#!/usr/bin/env bash
# Shared sandbox for the worktree evals. Source it from a case's setup.sh,
# with the current directory as the sandbox root. It builds:
#   remote.git  bare repo standing in for origin (origin/HEAD -> develop)
#   seed/       another clone, used to push branches the agent hasn't fetched
#   app/        the user's checkout, on feature/other with an unpushed commit,
#               untracked .env files, and a node_modules folder
#   home/       stands in for ~ (worktrees go in home/.worktrees)
set -eu
ROOT="$PWD"
export GIT_AUTHOR_NAME=Dev GIT_AUTHOR_EMAIL=dev@example.com
export GIT_COMMITTER_NAME=Dev GIT_COMMITTER_EMAIL=dev@example.com
mkdir -p home

git init -q --bare -b main remote.git
git clone -q remote.git seed 2>/dev/null
cd seed
cat > package.json <<'EOF'
{
  "name": "app",
  "version": "1.0.0",
  "private": true
}
EOF
cat > package-lock.json <<'EOF'
{
  "name": "app",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "app",
      "version": "1.0.0"
    }
  }
}
EOF
printf 'node_modules\n.env\n.env.local\n' > .gitignore
printf 'DATABASE_URL=\n' > .env.example
mkdir -p apps/web && echo 'export default function Page() {}' > apps/web/page.tsx
git add -A && git commit -q -m "chore: init"
git push -q origin main
git switch -q -c develop
echo 'export const feature = true' > apps/web/feature.ts
git add -A && git commit -q -m "feat(web): add feature flag"
git push -q origin develop
git -C "$ROOT/remote.git" symbolic-ref HEAD refs/heads/develop
cd "$ROOT"

git clone -q remote.git app 2>/dev/null
cd app
git switch -q -c feature/other origin/develop
echo 'wip' > apps/web/other.ts
git add -A && git commit -q -m "feat(web): start the other feature"
printf 'DATABASE_URL=postgres://localhost/app\n' > .env
printf 'NEXT_PUBLIC_API=http://localhost:3000\n' > apps/web/.env.local
mkdir -p node_modules/some-pkg && printf 'SECRET=from-a-dependency\n' > node_modules/some-pkg/.env
cd "$ROOT"
