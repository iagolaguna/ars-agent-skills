---
name: release
description: >-
  Use when the user names a release branch (a semver name such as
  0.0.1-alpha.0, or release/<version>) and wants that version cut, or asks to
  tag it, publish the GitHub release, promote it to main, or bring it back
  to develop. Also when that branch is missing its changelog entry or root
  package.json version.
---

# Release

Cut one version from a release branch onto `main`. The changelog is generated from conventional commits. This skill does not publish to npm and does not add release-please or a release workflow. If the project needs either, say so and stop.

It assumes a `develop` branch for daily work and `main` for released code. If the repo has no `develop`, skip the Backport section.

## Input

The user names the branch. Accept `0.0.1-alpha.0`, `release/0.0.1-alpha.0`, or `release/v0.0.1-alpha.0`. The version is the semver at the end, without a leading `v`. The tag is `v` plus that version. Stop if the name does not parse.

## Prepare

Check out that branch and fetch `origin`. The release range is the commits on `HEAD` whose patch is not already on `origin/main`. The script does that comparison. Stop if it is empty.

1. Generate the section with `node .agents/skills/release/changelog.mjs <version>` from the repo root. Prepend it to `CHANGELOG.md` under a `# Changelog` heading. Create the file if it is missing. If that version's heading is already there, leave it. The script exits non-zero when a subject is not a conventional commit or the range is empty. Fix the commit, don't hand-edit around it. Add a sentence by hand only for a migration step or a known gap the log cannot say.
2. Set the root `package.json` `version` to that semver. Leave workspace packages alone.
3. If either file changed, commit on the release branch as `chore(release): <version>`. Use the commit skill. Don't amend.
4. Run the project's check commands, the ones `AGENTS.md` lists as required before a PR. They have to pass before the PR. Fix failures on this branch.

## Pull request

Base is `main`. Title is `chore(release): <version>`. That title wins over the open-pr title rule.

Follow the open-pr skill with `--base main`, plus `--template release.md` when `.github/PULL_REQUEST_TEMPLATE/release.md` exists. Pass `--draft` when creating the PR. On an existing PR, don't change draft or ready. Tick a checkbox only when this session verified it.

Push the release branch if the remote doesn't have it. Never force-push.

## Tag

Do this only after the PR into `main` is merged. If it is still open, report the PR URL and stop.

1. Check out `main`, pull, and confirm the root `package.json` version matches.
2. Create an annotated tag `v<version>` on that commit: `git tag -a v<version> -m v<version>`. Stop if the tag exists.
3. `git push origin v<version>`.
4. Publish with `gh release create v<version> --target main --title v<version> --notes-file <file>`, using this version's changelog section as the notes.

## Backport

Do this after the tag is on `main`. `develop` keeps its own history. A rebase merge rewrites SHAs, so copy the patches `develop` does not already have. Don't rebase `develop` onto `main`, and don't force-push.

1. `git fetch origin`
2. List the commits: `git log --cherry-pick --right-only --reverse --format='%h %s' origin/develop...v<version>`
3. If the list is empty, `develop` already has the release. Say so.
4. Check out `develop` and pull. Cherry-pick that list in order with `git cherry-pick -x <sha>`. Stop on conflict.
5. Push `develop`.

## Stop

Stop and report when the branch is missing, the range is empty, checks fail, a push is rejected, or the PR is not merged yet. A rejected tag push is not a reason to delete the tag and retry with force.
