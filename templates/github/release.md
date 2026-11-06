<!--
Title: chore(release): <version>   e.g. chore(release): 0.2.0
Use this for the PR that promotes a release/* or hotfix/* branch to main. Open it as a draft until the preview is checked.
Merge with "Create a merge commit" (gh pr merge <n> --merge), never "Rebase and merge": a rebase rewrites the SHAs and breaks the back-merge into develop.
-->

## Release

Version: `<version>`
From: `<release/* or hotfix/* branch>` into `main`

<!-- Two or three lines: what this release is for and who it goes to. -->

## Changelog

<!-- Paste the generated entry from CHANGELOG.md. Hand-write only what the commit log can't say, like a migration step or a known gap. -->

### Not included

<!-- Open PRs or work that was left out on purpose, with the PR number. Delete if none. -->

## Checklist

- [ ] `package.json` version and `CHANGELOG.md` match the title
- [ ] Every commit in the range follows conventional commits, so the changelog is complete
- [ ] No `.env*` files committed
- [ ] Breaking changes and migration steps are called out above, or there are none

## Test plan

<!-- One box per check command AGENTS.md requires before a PR, plus the project's manual checks (preview, smoke test). Delete this comment. -->

- [ ] Checks from `AGENTS.md`

## After merge

- [ ] Tag `v<version>` on the merge commit and publish the GitHub release with the changelog entry
- [ ] `main` merged back into `develop` with a merge commit (`git merge-base --is-ancestor v<version> origin/develop`)
