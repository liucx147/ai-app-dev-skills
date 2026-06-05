#!/usr/bin/env bash
# validate-rag-pipeline.sh — Sanity-check a RAG project produced by the
# rag-pipeline-builder Skill.
#
# Validates (in order):
#   1. Required project files / directories exist.
#   2. Env vars declared in .env.example are present (set, or in .env, or in process env).
#   3. Project type auto-detected (Python via pyproject.toml or Node via package.json),
#      and core dependencies are installed in that toolchain.
#   4. Optional smoke test runs end-to-end (--with-smoke).
#
# Exits 0 on success, 1 on validation failure, 2 on usage error.
#
# Usage:
#   bash validate-rag-pipeline.sh --project-dir <path>
#   bash validate-rag-pipeline.sh --project-dir <path> --env-file <path>
#   bash validate-rag-pipeline.sh --project-dir <path> --with-smoke
#   bash validate-rag-pipeline.sh --project-dir <path> --skip-deps

set -euo pipefail

PROJECT_DIR=""
ENV_FILE=""
WITH_SMOKE="false"
SKIP_DEPS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    --env-file)    ENV_FILE="${2:-}";    shift 2 ;;
    --with-smoke)  WITH_SMOKE="true";    shift ;;
    --skip-deps)   SKIP_DEPS="true";     shift ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${PROJECT_DIR}" ]]; then
  echo "ERROR: --project-dir is required" >&2
  exit 2
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: project dir not found: ${PROJECT_DIR}" >&2
  exit 2
fi

cd "${PROJECT_DIR}"

PASS="✓"
FAIL="✗"
WARN="!"
errors=0

note()  { printf "  %s %s\n" "$1" "$2"; }
fail()  { note "${FAIL}" "$1"; errors=$((errors + 1)); }
pass()  { note "${PASS}" "$1"; }
warn()  { note "${WARN}" "$1"; }

echo "rag-pipeline-builder validator"
echo "  project : $(pwd)"
[[ "${WITH_SMOKE}" == "true" ]] && echo "  smoke   : on"
[[ "${SKIP_DEPS}" == "true" ]]  && echo "  deps    : skipped"
echo

# ---------------------------------------------------------------------------
# 1. Required files / directories
# ---------------------------------------------------------------------------
echo "[1/4] Required files & directories"

REQUIRED_FILES=(
  "README.md"
  ".env.example"
)
REQUIRED_DIRS=(
  "src"
  "src/ingest"
  "src/retrieve"
  "src/generate"
  "eval"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$f" ]]; then pass "$f"; else fail "$f (missing)"; fi
done
for d in "${REQUIRED_DIRS[@]}"; do
  if [[ -d "$d" ]]; then pass "$d/"; else fail "$d/ (missing)"; fi
done

echo

# ---------------------------------------------------------------------------
# 2. Environment variables declared in .env.example
# ---------------------------------------------------------------------------
echo "[2/4] Environment variables"

if [[ ! -f ".env.example" ]]; then
  warn "skipping (no .env.example)"
else
  EFFECTIVE_ENV_FILE="${ENV_FILE:-.env}"
  declare -A LOADED_ENV=()

  if [[ -f "${EFFECTIVE_ENV_FILE}" ]]; then
    pass "loading values from ${EFFECTIVE_ENV_FILE}"
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      LOADED_ENV["${key}"]="${val}"
    done < "${EFFECTIVE_ENV_FILE}"
  else
    warn "no ${EFFECTIVE_ENV_FILE} — falling back to process env"
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    key="${line%%=*}"
    [[ -z "$key" ]] && continue

    val="${LOADED_ENV[${key}]:-}"
    [[ -z "$val" ]] && val="${!key:-}"

    if [[ -z "$val" ]]; then
      fail "${key} (unset)"
    elif [[ "$val" == *PLACEHOLDER* || "$val" == "changeme" ]]; then
      fail "${key} (still a placeholder)"
    else
      pass "${key}"
    fi
  done < ".env.example"
fi

echo

# ---------------------------------------------------------------------------
# 3. Project type + dependencies
# ---------------------------------------------------------------------------
echo "[3/4] Project type & dependencies"

PROJECT_TYPE="unknown"
if [[ -f "pyproject.toml" || -f "requirements.txt" ]]; then
  PROJECT_TYPE="python"
elif [[ -f "package.json" ]]; then
  PROJECT_TYPE="node"
fi

pass "detected: ${PROJECT_TYPE}"

if [[ "${SKIP_DEPS}" == "true" ]]; then
  warn "dependency check skipped (--skip-deps)"
elif [[ "${PROJECT_TYPE}" == "python" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 not on PATH"
  else
    pass "python3 $(python3 --version 2>&1 | awk '{print $2}')"
    for pkg in anthropic numpy; do
      if python3 -c "import ${pkg}" >/dev/null 2>&1; then
        pass "import ${pkg}"
      else
        fail "import ${pkg} (run: pip install ${pkg})"
      fi
    done
  fi
elif [[ "${PROJECT_TYPE}" == "node" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    fail "node not on PATH"
  else
    pass "node $(node --version)"
    if [[ ! -d "node_modules" ]]; then
      fail "node_modules missing (run: npm install)"
    else
      pass "node_modules present"
    fi
  fi
else
  fail "could not detect Python or Node project (no pyproject.toml / requirements.txt / package.json)"
fi

echo

# ---------------------------------------------------------------------------
# 4. Optional smoke test
# ---------------------------------------------------------------------------
echo "[4/4] Smoke test"

if [[ "${WITH_SMOKE}" != "true" ]]; then
  warn "skipped (pass --with-smoke to enable)"
else
  SMOKE_SCRIPT=""
  for candidate in "tests/smoke.py" "scripts/smoke.py" "eval/smoke.py" "tests/smoke.ts" "scripts/smoke.ts"; do
    if [[ -f "$candidate" ]]; then
      SMOKE_SCRIPT="$candidate"
      break
    fi
  done

  if [[ -z "${SMOKE_SCRIPT}" ]]; then
    fail "no smoke script found (expected tests/smoke.{py,ts} or scripts/smoke.{py,ts})"
  else
    pass "running ${SMOKE_SCRIPT}"
    case "${SMOKE_SCRIPT}" in
      *.py) python3 "${SMOKE_SCRIPT}" || fail "smoke test failed" ;;
      *.ts) npx --yes tsx "${SMOKE_SCRIPT}" || fail "smoke test failed" ;;
    esac
  fi
fi

echo
if [[ "${errors}" -eq 0 ]]; then
  echo "All checks passed."
  exit 0
else
  echo "Validation failed: ${errors} error(s)."
  exit 1
fi
