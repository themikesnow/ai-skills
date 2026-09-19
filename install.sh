#!/usr/bin/env bash
#
# install.sh — link this repo's skills into Claude Code and Codex.
#
# The repo is the single source of truth. This script creates symlinks
# (or, for skills that opt into per-tool frontmatter, generates SKILL.md)
# in each tool's expected location. It is idempotent: re-run it any time
# you add a skill or set up a new machine.
#
# Usage:
#   ./install.sh              # link everything for both tools
#   ./install.sh --dry-run    # print what would happen, change nothing
#   ./install.sh --claude     # only Claude Code
#   ./install.sh --codex      # only Codex
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"
CODEX_HOME="$HOME/.codex"

DRY_RUN=0
DO_CLAUDE=1
DO_CODEX=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --claude)  DO_CODEX=0 ;;
    --codex)   DO_CLAUDE=0 ;;
    -h|--help)
      sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# link SRC DEST — force-replace DEST with a symlink to SRC, no nesting.
link() {
  local src="$1" dest="$2"
  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  echo "  linked $(basename "$dest") -> $src"
}

# A skill opts into per-tool frontmatter by containing a `variants/`
# dir with body.md + claude.md + codex.md instead of a plain SKILL.md.
# For those we GENERATE SKILL.md per tool; otherwise we symlink the folder.
generate_variant() {
  local skill_dir="$1" tool="$2" dest_dir="$3"
  local name; name="$(basename "$skill_dir")"
  run mkdir -p "$dest_dir/$name"
  # header (tool-specific frontmatter) + shared body
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] generate $dest_dir/$name/SKILL.md from variants/$tool.md + variants/body.md"
  else
    cat "$skill_dir/variants/$tool.md" "$skill_dir/variants/body.md" \
      > "$dest_dir/$name/SKILL.md"
  fi
  # templates are shared — symlink the dir
  link "$skill_dir/templates" "$dest_dir/$name/templates"
  echo "  generated $name/SKILL.md ($tool)"
}

install_skills_for() {
  local tool="$1" dest="$2"
  echo "[$tool] skills -> $dest"
  run mkdir -p "$dest"
  local skill
  for skill in "$REPO"/skills/*/; do
    [ -d "$skill" ] || continue
    local name; name="$(basename "$skill")"
    if [ -d "$skill/variants" ]; then
      generate_variant "$skill" "$tool" "$dest"
    else
      link "$skill" "$dest/$name"
    fi
  done
}

echo "repo: $REPO"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — no changes will be made)"

if [ "$DO_CLAUDE" -eq 1 ]; then
  install_skills_for claude "$CLAUDE_SKILLS"
fi

if [ "$DO_CODEX" -eq 1 ]; then
  install_skills_for codex "$CODEX_SKILLS"
  # Codex-only global instructions (no Claude equivalent)
  if [ -f "$REPO/codex/AGENTS.md" ]; then
    echo "[codex] global AGENTS.md"
    link "$REPO/codex/AGENTS.md" "$CODEX_HOME/AGENTS.md"
  fi
fi

echo "done."
if [ "$DRY_RUN" -eq 0 ]; then
  echo "verify: codex --print-instructions   (and check Claude's skill list)"
fi
