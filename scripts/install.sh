#!/usr/bin/env bash
# install.sh — Install ai-app-dev-skills into the user's Claude Code config.
#
# Two operating modes:
#   LOCAL  (default when run from inside a checkout): use the skills in this
#          directory. Supports symlinks (edits picked up live) or copies,
#          plus --target and --dry-run.
#   REMOTE (used by `curl | bash` or `--remote <url>`): shallow-clone the
#          repo to a temp dir, then run the local install.
#
# Usage:
#   # from a local checkout
#   bash scripts/install.sh
#   bash scripts/install.sh --target <dir>
#   bash scripts/install.sh --copy                # force copy, no symlink
#   bash scripts/install.sh --dry-run             # show actions, perform none
#
#   # one-liner remote install (no checkout required)
#   curl -fsSL https://raw.githubusercontent.com/liucx147/ai-app-dev-skills/main/scripts/install.sh | bash
#   curl ... | bash -s -- --target <dir>
#   curl ... | bash -s -- --copy
#
# Environment overrides:
#   CLAUDE_SKILLS_DIR   target directory (default: $HOME/.claude/skills)

set -euo pipefail

# --- repo metadata (update when forking) ---
DEFAULT_REPO_URL="https://github.com/liucx147/ai-app-dev-skills.git"

# --- runtime config (overridable via env) ---
TARGET="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

# --- flags ---
REPO_URL=""
MODE="symlink"
DRY_RUN="false"
ORIGINAL_ARGS=("$@")

print_help() {
  sed -n '2,32p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      # `--remote <url>` or `--remote` (uses default).
      if [[ "${2:-}" && "${2:0:1}" != "-" ]]; then
        REPO_URL="$2"
        shift 2
      else
        REPO_URL="$DEFAULT_REPO_URL"
        shift 1
      fi
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# --- source resolution ---
SKILLS_SRC=""
TMPDIR_CLONE=""

if [[ -n "${REPO_URL}" ]]; then
  # REMOTE mode — clone to a temp dir, then install from there.
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: --remote requires git on PATH" >&2
    exit 2
  fi
  TMPDIR_CLONE="$(mktemp -d)"
  trap '[[ -n "${TMPDIR_CLONE}" ]] && rm -rf "${TMPDIR_CLONE}"' EXIT
  echo "Cloning ${REPO_URL} (shallow)..."
  git clone --depth 1 --quiet "${REPO_URL}" "${TMPDIR_CLONE}/repo" 2>/dev/null || {
    echo "ERROR: failed to clone ${REPO_URL}" >&2
    exit 1
  }
  REPO_ROOT="${TMPDIR_CLONE}/repo"
  SKILLS_SRC="${REPO_ROOT}/skills"
else
  # LOCAL mode — use the current repo (this script's parent).
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  SKILLS_SRC="${REPO_ROOT}/skills"
fi

# --- output ---
echo "🚀 Installing ai-app-dev-skills..."
echo "📁 Target directory : ${TARGET}"
echo "🔗 Mode             : ${MODE}"
if [[ -n "${REPO_URL}" ]]; then
  echo "🌐 Source           : ${REPO_URL} (cloned)"
else
  echo "📂 Source           : ${SKILLS_SRC}"
fi
[[ "${DRY_RUN}" == "true" ]] && echo "🧪 Dry-run          : yes"
echo

if [[ ! -d "${SKILLS_SRC}" ]]; then
  echo "ERROR: skills directory missing: ${SKILLS_SRC}" >&2
  exit 1
fi

if [[ "${DRY_RUN}" != "true" ]]; then
  mkdir -p "${TARGET}"
fi

# --- install loop ---
installed=0
skipped=0

shopt -s nullglob
for skill_dir in "${SKILLS_SRC}"/*/; do
  skill_name="$(basename "${skill_dir}")"

  if [[ ! -f "${skill_dir}SKILL.md" ]]; then
    echo "  ⏭  ${skill_name} (no SKILL.md)"
    skipped=$((skipped + 1))
    continue
  fi

  dest="${TARGET}/${skill_name}"

  if [[ -L "${dest}" ]] || [[ -e "${dest}" ]]; then
    if [[ -L "${dest}" ]] && [[ "$(readlink "${dest}")" == "${skill_dir%/}" ]]; then
      echo "  ✓  ${skill_name} (already linked)"
      skipped=$((skipped + 1))
      continue
    fi
    echo "  ⚠  ${skill_name} already exists at ${dest} — leaving in place"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  🧪 would install ${skill_name} -> ${dest} (${MODE})"
    installed=$((installed + 1))
    continue
  fi

  case "${MODE}" in
    symlink)
      if ! ln -s "${skill_dir%/}" "${dest}" 2>/dev/null; then
        echo "  ⚠  symlink failed for ${skill_name}, falling back to copy"
        cp -R "${skill_dir%/}" "${dest}"
      fi
      ;;
    copy)
      cp -R "${skill_dir%/}" "${dest}"
      ;;
  esac

  echo "  ✅ ${skill_name}"
  installed=$((installed + 1))
done
shopt -u nullglob

echo
echo "🎉 Done. installed=${installed} skipped=${skipped}"
echo
echo "📦 Skills now in ${TARGET}:"
if [[ -d "${TARGET}" ]]; then
  ls -1 "${TARGET}" 2>/dev/null | grep -v '^\.' | sed 's/^/   - /' || echo "   (none)"
fi
echo
echo "💡 Restart Claude Code to activate the new Skills."
echo "📖 Documentation : ${REPO_URL:-${DEFAULT_REPO_URL}}"
