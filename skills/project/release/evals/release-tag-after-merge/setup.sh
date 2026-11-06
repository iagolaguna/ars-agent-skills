#!/usr/bin/env bash
# Builds the sandbox for this case in the current directory.
set -eu
source "$(cd "$(dirname "$0")" && pwd)/../fixture.sh"
git switch -q -c release/0.2.0 origin/develop
node -e 'const f="package.json",p=JSON.parse(require("fs").readFileSync(f));p.version="0.2.0";require("fs").writeFileSync(f,JSON.stringify(p,null,2)+"\n")'
printf "# Changelog\n\n## [0.2.0] - 2026-11-05\n\n### Features\n\n- web: add pricing page\n\n### Fixes\n\n- web: round prices to two decimals\n\n### Docs\n\n- document the pricing page\n\n%s\n" "$(tail -n +3 CHANGELOG.md)" > CHANGELOG.md
git add package.json CHANGELOG.md && git commit -q -m "chore(release): 0.2.0"
git push -q -u origin release/0.2.0
git switch -q main && git pull -q --ff-only origin main
git merge -q --no-ff release/0.2.0 -m "chore(release): 0.2.0"
M=$(git rev-parse HEAD)
git switch -q -c ci/cache-npm
commit "ci: cache npm in CI" .github/workflows/ci.yml
git switch -q main
git merge -q --no-ff ci/cache-npm -m "ci: cache npm in CI"
git branch -q -D ci/cache-npm
git push -q origin main
git switch -q develop
cat > "$ROOT/gh-state/prs.json" <<JSON
[{"number": 7, "state": "MERGED", "isDraft": false, "title": "chore(release): 0.2.0",
  "baseRefName": "main", "headRefName": "release/0.2.0", "url": "https://github.com/acme/app/pull/7",
  "mergeCommit": {"oid": "$M"}, "body": ""}]
JSON
