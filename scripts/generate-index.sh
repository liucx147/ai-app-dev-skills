#!/usr/bin/env bash
# generate-index.sh — Regenerate the Skill index section of README.md.
#
# Finds every skills/<name>/SKILL.md, extracts (name, description), and rewrites
# the block delimited by the markers below in README.md:
#
#   <!-- SKILL_INDEX:START -->
#   ...generated table...
#   <!-- SKILL_INDEX:END -->
#
# If the markers are missing, the script prints the generated table to stdout
# instead of editing the README, so it stays safe to run before the README has
# been wired up.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
README="${REPO_ROOT}/README.md"

if [[ ! -d "${SKILLS_DIR}" ]]; then
  echo "ERROR: skills directory missing: ${SKILLS_DIR}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 1
fi

GENERATED="$(python3 - "${SKILLS_DIR}" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml is required (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

ROOT = Path(sys.argv[1]).resolve()
FM = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

rows: list[tuple[str, str]] = []
for entry in sorted(ROOT.iterdir()):
    if not entry.is_dir() or entry.name.startswith("."):
        continue
    skill_md = entry / "SKILL.md"
    if not skill_md.is_file():
        continue
    raw = skill_md.read_text(encoding="utf-8")
    match = FM.match(raw)
    if not match:
        continue
    try:
        meta = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        continue
    name = meta.get("name") or entry.name
    desc = (meta.get("description") or "").strip().replace("|", "\\|").replace("\n", " ")
    rows.append((name, desc))

if not rows:
    print("_No Skills published yet._")
else:
    print("| Skill | Description |")
    print("| --- | --- |")
    for name, desc in rows:
        print(f"| [`{name}`](skills/{name}/SKILL.md) | {desc} |")
PY
)"

START_MARKER="<!-- SKILL_INDEX:START -->"
END_MARKER="<!-- SKILL_INDEX:END -->"

if [[ ! -f "${README}" ]] || ! grep -q "${START_MARKER}" "${README}"; then
  echo "Generated index (no markers in README.md, printing to stdout):"
  echo
  echo "${START_MARKER}"
  echo "${GENERATED}"
  echo "${END_MARKER}"
  exit 0
fi

python3 - "${README}" "${START_MARKER}" "${END_MARKER}" <<PY
import sys
from pathlib import Path

readme = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
generated = """${GENERATED}"""

text = readme.read_text(encoding="utf-8")
before, _, rest = text.partition(start)
_, _, after = rest.partition(end)
new = f"{before}{start}\n{generated}\n{end}{after}"
readme.write_text(new, encoding="utf-8")
print(f"Updated {readme}")
PY
