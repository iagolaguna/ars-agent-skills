#!/usr/bin/env bash
# Builds the sandbox for this case in the current directory.
set -eu
source "$(cd "$(dirname "$0")" && pwd)/../fixture.sh"
cd app
git worktree add -q -b feature/x "$ROOT/home/.worktrees/app-wt-feature-x" origin/develop
echo "// half done" >> "$ROOT/home/.worktrees/app-wt-feature-x/apps/web/page.tsx"
echo "notes" > "$ROOT/home/.worktrees/app-wt-feature-x/TODO.md"
cd "$ROOT"
