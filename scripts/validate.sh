#!/usr/bin/env bash
# validate.sh — Validate every SKILL.md in this repo against the project spec.
#
# Checks per Skill (skills/<name>/SKILL.md):
#   - Frontmatter parses as YAML.
#   - `name` is present, kebab-case, ≤ 64 chars, matches the directory name.
#   - `description` is present and 150–300 characters.
#   - Optional `allowed-tools` is either:
#       * a comma-separated string   (e.g. `Read, Write, Edit`)
#       * a YAML list                (e.g. `- Read` / `- Write`)
#   - Optional `disable-model-invocation` is a boolean when present.
#   - No absolute paths in the body (heuristic).
#
# Usage:
#   bash validate.sh                         # validate ./skills
#   bash validate.sh --skills-dir <path>     # validate a different directory
#                                            # (used by scripts/test-validate.sh)
#
# Exits non-zero on any failure. Designed to run in CI and locally.

set -euo pipefail

SKILLS_DIR_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir)
      SKILLS_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-${REPO_ROOT}/skills}"

if [[ ! -d "${SKILLS_DIR}" ]]; then
  echo "ERROR: skills directory missing: ${SKILLS_DIR}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to validate YAML frontmatter" >&2
  exit 1
fi

# Hand the heavy lifting to Python so we get reliable YAML parsing and
# unicode-correct length counts.
python3 - "${SKILLS_DIR}" <<'PY'
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml is required (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

ROOT = Path(sys.argv[1]).resolve()
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
ABS_PATH_HINTS = (
    re.compile(r"(^|[^\w])/Users/[A-Za-z0-9._-]+"),
    re.compile(r"(^|[^\w])/home/[A-Za-z0-9._-]+"),
    re.compile(r"[A-Z]:\\\\Users\\\\"),
)

failures: list[str] = []
checked = 0


def fail(skill: str, msg: str) -> None:
    failures.append(f"  ✗ {skill}: {msg}")


def check_skill(skill_dir: Path) -> None:
    global checked
    name = skill_dir.name
    skill_md = skill_dir / "SKILL.md"

    if not skill_md.is_file():
        fail(name, "missing SKILL.md")
        return

    checked += 1
    raw = skill_md.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(raw)
    if not match:
        fail(name, "SKILL.md is missing a YAML frontmatter block")
        return

    try:
        meta = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as exc:
        fail(name, f"invalid YAML frontmatter: {exc}")
        return

    if not isinstance(meta, dict):
        fail(name, "frontmatter must be a mapping")
        return

    fm_name = meta.get("name")
    if not isinstance(fm_name, str) or not fm_name:
        fail(name, "`name` field is required")
    else:
        if len(fm_name) > 64:
            fail(name, f"`name` exceeds 64 chars ({len(fm_name)})")
        if not NAME_RE.match(fm_name):
            fail(name, f"`name` must be kebab-case (got {fm_name!r})")
        if fm_name != name:
            fail(name, f"`name` ({fm_name!r}) must match directory name ({name!r})")

    desc = meta.get("description")
    if not isinstance(desc, str) or not desc.strip():
        fail(name, "`description` field is required")
    else:
        n = len(desc)
        if n < 150 or n > 300:
            fail(name, f"`description` must be 150–300 chars (got {n})")

    if "allowed-tools" in meta:
        tools = meta["allowed-tools"]
        if isinstance(tools, str):
            # comma-separated form: `Read, Write, Edit`
            parts = [t.strip() for t in tools.split(",") if t.strip()]
            if not parts:
                fail(name, "`allowed-tools` string has no tool names")
        elif isinstance(tools, list):
            # YAML list form (block: `- Read\n- Write` or flow: `[Read, Write]`)
            if not tools:
                fail(name, "`allowed-tools` list is empty")
            elif not all(isinstance(t, str) and t.strip() for t in tools):
                fail(name, "`allowed-tools` list must contain non-empty strings")
        else:
            fail(name, "`allowed-tools` must be a comma-separated string or a YAML list")

    if "disable-model-invocation" in meta:
        flag = meta["disable-model-invocation"]
        if not isinstance(flag, bool):
            fail(name, "`disable-model-invocation` must be a boolean")

    body = raw[match.end():]
    for pat in ABS_PATH_HINTS:
        hit = pat.search(body)
        if hit:
            fail(name, f"absolute-path-like string in body: {hit.group(0).strip()!r}")
            break


for entry in sorted(ROOT.iterdir()):
    if not entry.is_dir():
        continue
    if entry.name.startswith("."):
        continue
    check_skill(entry)

if checked == 0:
    print("No Skills found yet — nothing to validate.")
    sys.exit(0)

if failures:
    print(f"Validated {checked} Skill(s); {len(failures)} failure(s):")
    for line in failures:
        print(line)
    sys.exit(1)

print(f"Validated {checked} Skill(s) — all passed.")
PY
