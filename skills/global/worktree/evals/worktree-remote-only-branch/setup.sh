#!/usr/bin/env bash
# Builds the sandbox for this case in the current directory.
set -eu
source "$(cd "$(dirname "$0")" && pwd)/../fixture.sh"
cd seed
git switch -q -c fix/login origin/develop
echo "export const refresh = true" > apps/web/auth.ts
git add -A && git commit -q -m "fix(auth): handle expired tokens"
git push -q origin fix/login
cd "$ROOT"
