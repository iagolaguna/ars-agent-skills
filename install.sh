#!/usr/bin/env bash
# Install ars-agent-skills.
#
#   ./install.sh global             symlink skills/global/* into ~/.agents/skills
#   ./install.sh project <path>     copy skills/project/* into <path>/.agents/skills,
#                                   mirror them for Claude and Grok, set up OpenSpec
#
# .agents/skills is the canonical location. Claude Code only reads .claude/skills,
# and Grok only reads .grok/skills inside a project, so both get symlinks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRRORS=(.claude .grok)

link() { # link <target> <link-path>
  if [ -e "$2" ] || [ -L "$2" ]; then
    echo "skip   $2 (already exists)"
  else
    ln -s "$1" "$2"
    echo "link   $2"
  fi
}

install_global() {
  local dest="$HOME/.agents/skills"
  mkdir -p "$dest"
  for skill in "$ROOT"/skills/global/*/; do
    link "${skill%/}" "$dest/$(basename "$skill")"
  done
  # Grok and most agents read ~/.agents/skills. Claude reads ~/.claude/skills.
  if [ ! -e "$HOME/.claude/skills" ]; then
    mkdir -p "$HOME/.claude"
    ln -s "$dest" "$HOME/.claude/skills"
    echo "link   ~/.claude/skills -> $dest"
  fi
}

install_project() {
  local project="${1:?usage: ./install.sh project <path>}"
  project="$(cd "$project" && pwd)"
  local dest="$project/.agents/skills"
  mkdir -p "$dest"

  for skill in "$ROOT"/skills/project/*/; do
    local name; name="$(basename "$skill")"
    if [ -e "$dest/$name" ]; then
      echo "skip   .agents/skills/$name (already exists)"
    else
      cp -R "${skill%/}" "$dest/$name"
      echo "copy   .agents/skills/$name"
    fi
  done

  # Mirror every non-OpenSpec skill. OpenSpec writes its own copies per tool.
  for mirror in "${MIRRORS[@]}"; do
    mkdir -p "$project/$mirror/skills"
    for skill in "$dest"/*/; do
      local name; name="$(basename "$skill")"
      case "$name" in openspec-*) continue ;; esac
      link "../../.agents/skills/$name" "$project/$mirror/skills/$name"
    done
  done

  if command -v openspec >/dev/null 2>&1; then
    if [ ! -f "$project/openspec/config.yaml" ]; then
      mkdir -p "$project/openspec"
      cp "$ROOT/templates/openspec/config.yaml" "$project/openspec/config.yaml"
      echo "copy   openspec/config.yaml (fill in the placeholders)"
    fi
    openspec init --tools claude,agents,grok --no-animation "$project"
  else
    echo "openspec not found, skipping. Install it with: npm i -g @fission-ai/openspec"
  fi
}

case "${1:-}" in
  global) install_global ;;
  project) shift; install_project "$@" ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
