---
name: release
description: >-
  Cuts a version git-flow style: release branch from develop, changelog from
  conventional commits, PR into main with a merge commit, tag and GitHub
  release on that merge commit, then main merged back into develop. Also
  handles hotfixes off main. Use when the user wants a version cut or shipped
  ("release 0.2.0", "faz o release", "cut release/1.4.0"), names a release or
  hotfix branch, asks to tag or publish a GitHub release, promote to main, or
  merge main back into develop, or when a release branch is missing its
  changelog entry or root package.json version.
---

# Release

Cut one version from `develop` onto `main`, git-flow style. The release branch merges into `main` with a merge commit, and `main` merges back into `develop` the same way. Commits keep their SHAs on every branch, so nothing is cherry-picked and "is this on develop?" is answered by ancestry, not by comparing patches. The changelog is generated from conventional commits.

This skill does not publish to npm and does not add release-please or a release workflow. If the project needs either, say so and stop. It needs a `develop` branch. If the repo has none, say this flow doesn't fit and stop.

Project-specific checks (test, lint, contrast, smoke tests) are not listed here. They live in the project's `AGENTS.md`, under the commands required before a PR.

## Merge methods

| PR | Method | Why |
|---|---|---|
| feature, fix, chore → `develop` | Rebase and merge | Linear history inside `develop` |
| `release/*`, `hotfix/*` → `main` | Merge commit | Keeps the SHAs, so `main` stays reachable from `develop` |
| `main` → `develop` (back-merge) | Merge commit | Same |

GitHub's rebase merge rewrites every SHA, even when a fast-forward was possible. A rebase merge into `main` leaves copies that can't be merged back cleanly. Repo settings can't enforce one method per branch on every plan, so don't leave it to whoever clicks. When the user asks you to merge one of these PRs, do it with the method from the table: `gh pr merge <n> --merge` or `gh pr merge <n> --rebase`. Never merge without being asked.

Set the repo to use the PR title as the merge commit subject (`merge_commit_title=PR_TITLE`), so the merge commits on `main` stay conventional.

## Input

Accept a version (`0.2.0`), `release/<version>`, `release/v<version>`, or `hotfix/<version>`. The version is the semver at the end, without a leading `v`. The tag is `v` plus that version. Stop if it does not parse.

If a branch with the given name exists locally or on `origin`, use it. Otherwise create `release/<version>`, or `hotfix/<version>` for a hotfix, without the `v`.

## Cut

`git fetch origin`. If the release branch doesn't exist yet, create it from develop: `git switch -c release/<version> origin/develop`. Everything on `develop` at that moment is in scope. Work that must not ship goes in behind a flag or is merged after the cut. Release fixes are committed on the release branch and reach `develop` through the back-merge.

## Prepare

The release range is the commits on `HEAD` that `origin/main` cannot reach (`git log --no-merges origin/main..HEAD`). The script computes it. Stop if it is empty.

1. Generate the section with `node <this skill's directory>/changelog.mjs <version>`, run from the repo root. Prepend it to `CHANGELOG.md` under a `# Changelog` heading. Create the file if it is missing. If that version's heading is already there, leave it.
2. Set the root `package.json` `version` to that semver. Leave workspace packages alone.
3. If either file changed, commit on the release branch as `chore(release): <version>`. Use the commit skill. Don't amend.
4. Run the check commands `AGENTS.md` lists as required before a PR. They have to pass before the PR. Fix failures on this branch.

The script exits non-zero when the range is empty or a subject is not a conventional commit. A bad subject can only be reworded while the commit exists solely on this branch and hasn't been pushed. Once it is on `develop` or `main`, rewording means rewriting a shared branch, which is off the table. In that case show the user the commits the script listed and ask. If they agree, rerun with `--lenient`, which leaves those commits out, and write their lines into the section by hand. Otherwise add a sentence by hand only for a migration step or a known gap the log cannot say.

Moving a repo off rebase merges: the first release after the switch also needs `--since <ref>`, where `<ref>` is the last commit on `develop` that already shipped. Before that point, `develop` holds rebase copies of patches that are already on `main`, and without the flag they get listed again. Record the ref in the project's `AGENTS.md` or decision log, and drop it once that release is on `main`.

## Pull request

Base is `main`. Title is `chore(release): <version>`. That title wins over the open-pr title rule, and it becomes the merge commit subject.

Follow the open-pr skill with `--base main`, plus `--template release.md` when `.github/PULL_REQUEST_TEMPLATE/release.md` exists. Pass `--draft` when creating the PR. On an existing PR, don't change draft or ready. Tick a checkbox only when this session verified it. It merges with a merge commit.

Push the release branch if the remote doesn't have it. Never force-push.

## Tag

Do this only after the PR into `main` is merged. If it is still open, report the PR URL and stop.

1. Get the merge commit from the PR itself: `gh pr view <n> --json state,mergeCommit --jq .mergeCommit.oid`. Don't take the tip of `main`; something else may have merged since.
2. `git fetch origin`. Confirm that commit has two parents (`git rev-list --parents -1 <sha>`) and that the root `package.json` version in it matches (`git show <sha>:package.json`). One parent means the PR was rebase-merged: stop and report it, because the back-merge won't be clean.
3. Create an annotated tag on that commit: `git tag -a v<version> -m v<version> <sha>`. Stop if the tag exists.
4. `git push origin v<version>`.
5. Publish with `gh release create v<version> --target <sha> --title v<version> --notes-file <file>`, using this version's changelog section as the notes.

## Back-merge

Do this after the tag is on `main`. It brings the `chore(release)` commit and any release fixes into `develop`.

1. `git fetch origin`. If `git merge-base --is-ancestor v<version> origin/develop` succeeds, `develop` already has it. Say so and stop.
2. Open a PR with head `main` and base `develop`, titled `chore(release): merge v<version> into develop`. It merges with a merge commit.
3. If GitHub reports a conflict, don't resolve it on `main`. Run `git switch -c chore/back-merge-v<version> origin/develop`, then `git merge --no-ff origin/main`, resolve, run the checks from `AGENTS.md`, push, and open that branch as the PR into `develop` instead (same title, merge commit).
4. After it merges, confirm `git merge-base --is-ancestor v<version> origin/develop`.

If the repo has `delete_branch_on_merge` turned on, the PR with head `main` can make GitHub try to delete `main`. In that repo, always use the `chore/back-merge-v<version>` branch.

Once both merges are done, offer to delete the release branch, locally and on `origin`. Delete it only when the user says yes.

## Hotfix

A fix that can't wait for the next release from `develop`.

1. `git switch -c hotfix/<version> origin/main`, where `<version>` is the next patch or prerelease number.
2. Commit the fix, then run Prepare on this branch as written. The range is just the fix.
3. Run Pull request, Tag, and Back-merge as above, with the hotfix branch in place of the release branch and the title `chore(release): <version>`.

If a `release/*` branch is open when the hotfix lands, merge `main` into it too, or the release PR will conflict. Never bring a hotfix into `develop` by cherry-pick.

## Reading history

`main` and `develop` are no longer linear. Read them with `git log --first-parent`. Revert a whole release with `git revert -m 1 <merge sha>`.

## Stop

Stop and report when the branch is missing, the range is empty, checks fail, a push is rejected, a PR is not merged yet, or a PR into `main` was rebase-merged instead of merge-committed. A rejected tag push is not a reason to delete the tag and retry with force.
