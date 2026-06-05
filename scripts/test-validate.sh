#!/usr/bin/env bash
# test-validate.sh — Smoke tests for scripts/validate.sh's allowed-tools logic.
#
# Creates temporary fixture Skills with different `allowed-tools` shapes and
# asserts that validate.sh handles each correctly:
#
#   Case A — comma-separated string          → expected PASS
#   Case B — YAML block list                 → expected PASS
#   Case C — non-string non-list (integer)   → expected FAIL
#
# Run from anywhere:
#   bash scripts/test-validate.sh
#
# Exits 0 if every case produces the expected outcome, non-zero otherwise.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE="${REPO_ROOT}/scripts/validate.sh"

if [[ ! -x "${VALIDATE}" && ! -f "${VALIDATE}" ]]; then
  echo "ERROR: cannot find ${VALIDATE}" >&2
  exit 2
fi

TMP="$(mktemp -d -t aads-validate.XXXXXX)"
trap 'rm -rf "${TMP}"' EXIT

passed=0
failed=0

assert_pass() {
  local label="$1" dir="$2"
  if bash "${VALIDATE}" --skills-dir "${dir}" >/dev/null 2>&1; then
    printf "  ✓ %s\n" "${label}"
    passed=$((passed + 1))
  else
    printf "  ✗ %s (expected PASS, got FAIL)\n" "${label}"
    bash "${VALIDATE}" --skills-dir "${dir}" 2>&1 | sed 's/^/      /' || true
    failed=$((failed + 1))
  fi
}

assert_fail() {
  local label="$1" dir="$2"
  if bash "${VALIDATE}" --skills-dir "${dir}" >/dev/null 2>&1; then
    printf "  ✗ %s (expected FAIL, got PASS)\n" "${label}"
    failed=$((failed + 1))
  else
    printf "  ✓ %s\n" "${label}"
    passed=$((passed + 1))
  fi
}

# 200-char description — safely inside the 150–300 window so the only signal
# we test is the allowed-tools branch.
DESC='Use when fixture testing the validator allowed-tools handling, exercising the YAML parser branch for comma-separated strings versus block list syntax, plus the rejection path for invalid scalar types.'

mkfixture() {
  local root="$1" name="$2" tools_block="$3"
  mkdir -p "${root}/${name}"
  {
    printf -- '---\n'
    printf 'name: %s\n' "${name}"
    printf 'description: %s\n' "${DESC}"
    printf '%s\n' "${tools_block}"
    printf -- '---\n\n'
    printf '# %s\n\nFixture body. Step 1. Step 2.\n' "${name}"
  } > "${root}/${name}/SKILL.md"
}

echo "test-validate.sh"
echo "  validator : ${VALIDATE}"
echo "  fixtures  : ${TMP}"
echo

# ---------------------------------------------------------------------------
# Case A — comma-separated string
# ---------------------------------------------------------------------------
A="${TMP}/case-a"; mkdir -p "${A}"
mkfixture "${A}" "fixture-comma-string" "allowed-tools: Read, Write, Edit, Bash"
assert_pass "case A — comma-separated string parses & validates" "${A}"

# ---------------------------------------------------------------------------
# Case B — YAML block list
# ---------------------------------------------------------------------------
B="${TMP}/case-b"; mkdir -p "${B}"
LIST_BLOCK=$'allowed-tools:\n  - Read\n  - Write\n  - Edit\n  - Bash'
mkfixture "${B}" "fixture-yaml-list" "${LIST_BLOCK}"
assert_pass "case B — YAML block list parses & validates" "${B}"

# ---------------------------------------------------------------------------
# Case C — invalid scalar (integer) must be rejected
# ---------------------------------------------------------------------------
C="${TMP}/case-c"; mkdir -p "${C}"
mkfixture "${C}" "fixture-invalid-tools" "allowed-tools: 42"
assert_fail "case C — non-string non-list rejected" "${C}"

echo
printf "passed: %d   failed: %d\n" "${passed}" "${failed}"
[[ "${failed}" -eq 0 ]]
