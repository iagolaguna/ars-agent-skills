#!/usr/bin/env bash
# Install ars-agent-skills.
#
#   ./install.sh global             symlink skills/global/* into ~/.agents/skills
#   ./install.sh project <path>     copy skills/project/* into <path>/.agents/skills,
#                                   mirror them for Claude Code, add the release PR
#                                   template, set up OpenSpec
#   ./install.sh diff <path>        show where <path>'s copies of the project skills
#                                   differ from this repo
#
# .agents/skills is the canonical location. Grok, Codex, Cursor and most agents
# read it directly. Claude Code only reads .claude/skills, so it gets symlinks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRRORS=(.claude)

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
  # Most agents read ~/.agents/skills. Claude Code only reads ~/.claude/skills.
  if [ ! -e "$HOME/.claude/skills" ] && [ ! -L "$HOME/.claude/skills" ]; then
    mkdir -p "$HOME/.claude"
    ln -s "$dest" "$HOME/.claude/skills"
    echo "link   ~/.claude/skills -> $dest"
  elif [ "$(cd "$HOME/.claude/skills" && pwd -P)" != "$(cd "$dest" && pwd -P)" ]; then
    echo "note   ~/.claude/skills is not $dest, linking each skill into it"
    for skill in "$ROOT"/skills/global/*/; do
      link "${skill%/}" "$HOME/.claude/skills/$(basename "$skill")"
    done
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

  local template="$project/.github/PULL_REQUEST_TEMPLATE/release.md"
  if [ -e "$template" ]; then
    echo "skip   .github/PULL_REQUEST_TEMPLATE/release.md (already exists)"
  else
    mkdir -p "$(dirname "$template")"
    cp "$ROOT/templates/github/release.md" "$template"
    echo "copy   .github/PULL_REQUEST_TEMPLATE/release.md"
  fi

  if command -v openspec >/dev/null 2>&1; then
    if [ ! -f "$project/openspec/config.yaml" ]; then
      mkdir -p "$project/openspec"
      cp "$ROOT/templates/openspec/config.yaml" "$project/openspec/config.yaml"
      echo "copy   openspec/config.yaml (fill in the placeholders)"
    fi
    openspec init --tools claude,agents --no-animation "$project"
  else
    echo "openspec not found, skipping. Install it with: npm i -g @fission-ai/openspec"
  fi
}

diff_project() {
  local project="${1:?usage: ./install.sh diff <path>}"
  project="$(cd "$project" && pwd)"
  local status=0
  for skill in "$ROOT"/skills/project/*/; do
    local name; name="$(basename "$skill")"
    local copy="$project/.agents/skills/$name"
    if [ ! -e "$copy" ]; then
      echo "missing .agents/skills/$name"
    elif ! diff -ru "${skill%/}" "$copy"; then
      status=1
    fi
  done
  if [ -e "$project/.github/PULL_REQUEST_TEMPLATE/release.md" ]; then
    diff -u "$ROOT/templates/github/release.md" "$project/.github/PULL_REQUEST_TEMPLATE/release.md" || status=1
  fi
  [ "$status" -eq 0 ] && echo "same   every project skill matches this repo"
  return "$status"
}

case "${1:-}" in
  global) install_global ;;
  project) shift; install_project "$@" ;;
  diff) shift; diff_project "$@" ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
