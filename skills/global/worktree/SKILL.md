---
name: worktree
description: >-
  Creates or removes a git worktree in ~/.worktrees, branched from the repo's
  default branch, with the untracked .env* files copied over and dependencies
  installed. Use when the user wants a worktree, a parallel or isolated copy of
  the repo to work on another branch, or to clean one up ("/worktree feat/x",
  "cria uma worktree pra essa feature", "remove the worktree for fix/y").
user-invocable: true
---

# worktree

Create or remove a worktree from a single branch name. Don't modify files in the original checkout.

- `/worktree <branch>`: create (the default when there is no subcommand)
- `/worktree remove <branch>`: remove

Paths, for both:

- Repo root: `git rev-parse --show-toplevel`. If you are already inside a worktree, use the main checkout: `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`.
- Worktree path: `~/.worktrees/<repo-name>-wt-<branch>`, with every `/` in the branch name replaced by `-`.

## Create

### 1. Branch name and base

If the user gave only a description, build a name with the repo's convention. Use the `conventional-branch` skill when it is available (`feature/`, `fix/`, `chore/`, ... in lowercase kebab-case).

`git fetch origin`, then find where the branch comes from:

- Local branch exists (`git show-ref --verify --quiet refs/heads/<branch>`): `git worktree add <path> <branch>`.
- Only on the remote (`git show-ref --verify --quiet refs/remotes/origin/<branch>`): `git worktree add --track -b <branch> <path> origin/<branch>`.
- New branch: base it on the remote default branch, not on whatever is checked out. Get it with `git symbolic-ref --short refs/remotes/origin/HEAD` (in a git-flow repo that is usually `origin/develop`), fall back to `origin/main`, and run `git worktree add -b <branch> <path> <base>`. Use another base only when the user names one.

If it fails (the branch is checked out elsewhere, the path exists), report the error and stop.

### 2. Copy the env files

Find the `.env*` files that git doesn't track, without walking into dependencies:

```bash
cd <repo-root>
find . \( -name node_modules -o -name .git -o -name .venv -o -name dist -o -name .next \) -prune \
  -o -name '.env*' -type f -print
```

Skip any file `git ls-files --error-unmatch <file>` reports as tracked, like `.env.example`; the checkout already has it. Copy the rest to the same relative path inside the worktree, creating parent directories as needed.

### 3. Install dependencies

Use the lockfile in the worktree to pick the package manager, and don't let the install rewrite it:

| Lockfile | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |
| `yarn.lock` | `yarn install --immutable` (Yarn 2+) or `yarn install --frozen-lockfile` (Yarn 1) |
| `bun.lock` / `bun.lockb` | `bun install --frozen-lockfile` |
| `uv.lock` | `uv sync --frozen` |

No lockfile: skip this step. If the install fails, report it and keep the worktree.

### 4. Report

Worktree path, branch, the base it came from, the env files copied, and the install result.

## Remove

1. If the current directory is inside the worktree, `cd` to the repo root first.
2. `git worktree remove <path>`. If it refuses because of uncommitted or untracked changes, show `git -C <path> status --short` and ask before running it again with `--force`.
3. The branch stays. Offer to delete it with `git branch -d <branch>` (never `-D` without asking), and never delete the remote branch.
4. Report the path removed and what happened to the branch.
