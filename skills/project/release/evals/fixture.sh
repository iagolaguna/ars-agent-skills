#!/usr/bin/env bash
# Shared sandbox for the release evals. Source it from a case's setup.sh,
# with the current directory as the sandbox root. It builds:
#   remote.git   bare repo standing in for origin (origin/HEAD -> develop)
#   app/         the clone the agent works in
#   bin/gh       a fake GitHub CLI: logs every call to gh-calls.log and keeps
#                PRs and releases in gh-state/, never touches the network
# SKILL_DIR is the release skill to install into app/.agents/skills/release
# (defaults to the skill that holds these evals).
set -eu
EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SKILL_DIR:-$(cd "$EVALS_DIR/.." && pwd)}"
ROOT="$PWD"
export GIT_AUTHOR_NAME=Dev GIT_AUTHOR_EMAIL=dev@example.com
export GIT_COMMITTER_NAME=Dev GIT_COMMITTER_EMAIL=dev@example.com

mkdir -p bin gh-state home
echo '[]' > gh-state/prs.json
: > gh-calls.log
cat > bin/gh <<'PY'
#!/usr/bin/env python3
import json, os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE = os.path.join(ROOT, "gh-state")
args = sys.argv[1:]
with open(os.path.join(ROOT, "gh-calls.log"), "a") as log:
    log.write("gh " + " ".join(args) + "\n")
def opt(name):
    return args[args.index(name) + 1] if name in args and args.index(name) + 1 < len(args) else None
def out(obj):
    jq = opt("--jq") or opt("-q")
    text = json.dumps(obj)
    if jq:
        text = subprocess.run(["jq", "-r", jq], input=text, capture_output=True, text=True).stdout.rstrip("\n")
    print(text)
def prs():
    return json.load(open(os.path.join(STATE, "prs.json")))
def save(p):
    json.dump(p, open(os.path.join(STATE, "prs.json"), "w"), indent=2)
def branch():
    return subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
cmd = " ".join(args[:2])
if cmd == "pr view":
    sel = args[2] if len(args) > 2 and not args[2].startswith("-") else branch()
    sel = sel.lstrip("#")
    for p in prs():
        if str(p["number"]) == sel or p["headRefName"] == sel:
            out(p); sys.exit(0)
    print(f'no pull requests found for branch "{sel}"', file=sys.stderr); sys.exit(1)
elif cmd == "pr list":
    out(prs())
elif cmd == "pr create":
    p = prs(); n = 7 + len(p)
    pr = {"number": n, "state": "OPEN", "isDraft": "--draft" in args or "-d" in args,
          "title": opt("--title") or opt("-t") or "", "baseRefName": opt("--base") or opt("-B") or "develop",
          "headRefName": opt("--head") or opt("-H") or branch(), "url": f"https://github.com/acme/app/pull/{n}",
          "mergeCommit": None, "body": ""}
    bf = opt("--body-file") or opt("-F")
    if bf: pr["body"] = open(bf).read()
    elif opt("--body") or opt("-b"): pr["body"] = opt("--body") or opt("-b")
    p.append(pr); save(p); print(pr["url"])
elif cmd == "pr edit":
    print("https://github.com/acme/app/pull/" + args[2])
elif cmd == "pr merge":
    print("gh pr merge is not available in this sandbox", file=sys.stderr); sys.exit(1)
elif cmd == "release create":
    tag = args[2]
    nf = opt("--notes-file") or opt("-F")
    notes = open(nf).read() if nf else (opt("--notes") or opt("-n") or "")
    open(os.path.join(STATE, f"release-{tag}.md"), "w").write(notes)
    print(f"https://github.com/acme/app/releases/tag/{tag}")
elif cmd == "repo view":
    out({"nameWithOwner": "acme/app", "defaultBranchRef": {"name": "develop"}})
else:
    print(f"gh {' '.join(args)}: not available in this sandbox", file=sys.stderr); sys.exit(1)
PY
chmod +x bin/gh

git init -q --bare -b main remote.git
git init -q -b main app
cd app
git remote add origin "$ROOT/remote.git"

mkdir -p scripts .agents/skills .github/PULL_REQUEST_TEMPLATE
cat > package.json <<'EOF'
{
  "name": "app",
  "version": "0.1.0",
  "private": true,
  "scripts": { "check": "node scripts/check.js" }
}
EOF
cat > scripts/check.js <<'EOF'
// Stand-in for the project's checks. Records each run so the eval can see it.
const fs = require("node:fs")
fs.appendFileSync(".git/check-ran", `${new Date().toISOString()}\n`)
console.log("check: lint, typecheck, test, build ... ok")
EOF
cat > AGENTS.md <<'EOF'
# AGENTS.md

Node app. Work lands on `develop`; `main` holds released code.

## Commands

| Task | Command |
|---|---|
| Install | `npm install` |
| All checks | `npm run check` |

Run `npm run check` before opening a PR. It is the only required check.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## [0.1.0] - 2026-10-01

### Features

- first version (0000000)
EOF
cat > .github/PULL_REQUEST_TEMPLATE/release.md <<'EOF'
<!-- Title: chore(release): <version>. Merge with a merge commit. -->

## Release

Version: `<version>`

## Changelog

<!-- Paste this version's CHANGELOG section. -->

## Test plan

- [ ] `npm run check`
EOF
printf 'node_modules\n.env*\n' > .gitignore
mkdir -p .agents/skills/release
(cd "$SKILL_DIR" && tar --exclude=evals -cf - .) | (cd .agents/skills/release && tar -xf -)
git add -A && git commit -q -m "chore: init"
git tag -a v0.1.0 -m v0.1.0
git push -q origin main v0.1.0
git switch -q -c develop
git push -q -u origin develop
git -C "$ROOT/remote.git" symbolic-ref HEAD refs/heads/develop
git remote set-head origin develop >/dev/null

commit() { # commit <subject> [file]
  local f="${2:-src/$(echo "$1" | tr -c 'a-z0-9' '-' | cut -c1-30).txt}"
  mkdir -p "$(dirname "$f")"; echo "$1 $RANDOM" >> "$f"; git add "$f"; git commit -q -m "$1"
}
bump() { # bump <version>: set package.json version and add a CHANGELOG section
  node -e 'const f="package.json",p=JSON.parse(require("fs").readFileSync(f));p.version=process.argv[1];require("fs").writeFileSync(f,JSON.stringify(p,null,2)+"\n")' "$1"
  printf '# Changelog\n\n## [%s] - 2026-10-20\n\n### Fixes\n\n- api: handle empty cart\n\n%s\n' "$1" "$(tail -n +3 CHANGELOG.md)" > CHANGELOG.md
  git add package.json CHANGELOG.md; git commit -q -m "chore(release): $1"
}

# History shared by every case: a feature on develop, a hotfix 0.1.1 merged
# into main with a merge commit and merged back into develop, then more work.
commit "feat(web): add pricing page"
git switch -q -c hotfix/0.1.1 origin/main
commit "fix(api): handle empty cart"
bump 0.1.1
git switch -q main
git merge -q --no-ff hotfix/0.1.1 -m "chore(release): 0.1.1"
git tag -a v0.1.1 -m v0.1.1
git branch -q -D hotfix/0.1.1
git push -q origin main v0.1.1
git switch -q develop
git merge -q --no-ff main -m "chore(release): merge v0.1.1 into develop"
commit "feat(web): add dark mode"
commit "docs: document the pricing page" docs/pricing.md
git revert --no-edit HEAD~1 >/dev/null
commit "fix(web): round prices to two decimals"
git push -q origin develop
