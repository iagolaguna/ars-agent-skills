---
name: open-pr
description: >-
  Writes the title and body for the current branch's pull request and applies them: creates the PR if none
  exists, or updates the existing one with `gh pr edit`. The title is a conventional commit, the body is
  filled from the repo's own PR template (`.github/pull_request_template.md` or
  `.github/PULL_REQUEST_TEMPLATE/*.md`), and a Jira key found in the branch or commits is linked.
  Use whenever a PR needs a proper title and description.
  Triggers: "/open-pr", "open a PR", "write the PR description", "update the PR body".
user-invocable: true
---

# open-pr

Produce a PR title and body from what the branch actually contains, then apply them. One PR per branch:
update it if it exists, create it if it doesn't.

Arguments (all optional): `--base <branch>`, `--draft`, `--template <name>`, `--dry-run` (print title and
body, change nothing).

## 1. Gather

```bash
branch=$(git branch --show-current)
gh pr view --json number,url,baseRefName,title,body,isDraft 2>/dev/null   # existing PR, if any
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
```

Base branch, first match wins: `--base`, the existing PR's `baseRefName`, the repo default branch.
Stop if `branch` equals the base.

```bash
git fetch origin "$base" --quiet
git log --format='%h %s%n%b' "origin/$base..HEAD"
git diff --stat "origin/$base...HEAD"
git diff "origin/$base...HEAD"            # read it; the body describes the diff, not just the commit messages
```

Stop with a message if there are no commits ahead of the base.

## 2. Jira

Look for a key matching `[A-Z][A-Z0-9]+-[0-9]+` in the branch name first, then in commit subjects and bodies.
Take the first one. If `JIRA_BASE_URL` is set, link it as `[KEY]($JIRA_BASE_URL/browse/KEY)`; otherwise write
the bare key (GitHub autolinks it when the repo has an autolink reference). If no key is found, add nothing.
Never invent one and never ask for one.

## 3. Title

Conventional commit: `type(scope): summary`, at most 72 characters, imperative, lowercase, no period.

- One commit on the branch: reuse its subject unless it is vague ("wip", "fixes").
- Several commits: `type` is the most significant one present (`feat` > `fix` > `perf` > `refactor` >
  `docs` > `test` > `build` > `ci` > `chore`). A branch whose only commit is `spec: ...` keeps the `spec:` type.
- `scope` is the package or app that most of the diff touches (`web`, `ui`, ...), taken from the scopes the
  repo already uses in `git log`. Omit it when the change spans the whole repo.
- Breaking change in any commit (`!` or `BREAKING CHANGE:`): add `!` before the colon.
- Don't put the Jira key in the title unless the repo's recent PR titles do.

## 4. Pick the template

1. `--template <name>` → `.github/PULL_REQUEST_TEMPLATE/<name>.md`.
2. Otherwise, when `.github/PULL_REQUEST_TEMPLATE/` exists, choose by what the diff is. Read the comment at
   the top of each template; it usually says when to use it. Typical mapping: `spec:` → `spec.md`,
   `chore`/`ci`/`build` → `chore.md`, a diff confined to the design-system package → `design-system.md`,
   a user-facing feature → `feature.md`.
3. Otherwise `.github/pull_request_template.md` (also check the repo root and `docs/`).
4. No template at all: use `## Summary` and `## Test plan`.

## 5. Fill the body

- Keep the template's headings and order. Remove every HTML comment once you have acted on it.
- Delete sections the template says to delete when they don't apply. Don't leave empty headings or
  placeholders like `<name>`.
- **Summary**: what changes and why, written for a reviewer who hasn't seen the work. Bullets for distinct
  changes; group by package when the diff spans several. Link the spec or design doc if the branch has one.
- **Checkboxes**: tick one only when you verified it, either because you ran it in this session and it
  passed, or because the diff shows it plainly. Leave the rest unticked. If the reason isn't obvious, add a
  short note after the box. Never tick a test command you did not run.
- **Jira**: put the link on its own line right under the Summary heading.
- **Screenshots**: if the template asks for them and you have none, leave one line saying so.
- Prose: plain and specific. No filler intros, no "This PR...", no restating the title, no emoji headings.
- End with the PR attribution line from the session's system reminder, if there is one.
- Existing PR: if its body has content a human added (not a template placeholder and not your previous
  output), keep it under its original heading instead of overwriting it.

## 6. Apply

Write the body to a temp file and pass it with `--body-file`. That avoids shell quoting problems.

```bash
body=$(mktemp); cat > "$body" <<'EOF'
...
EOF
```

- `--dry-run`: print the title and body and stop.
- Branch not on the remote, or local commits ahead of it: `git push -u origin HEAD`. Never force-push. If the
  push is rejected, stop and report it.
- PR exists: `gh pr edit <number> --title "<title>" --body-file "$body"`.
- No PR: `gh pr create --base "$base" --title "<title>" --body-file "$body"`, plus `--draft` when asked for or
  when the title type is `spec`.
- Don't change draft/ready state on an existing PR. Leave that to the user.

Don't merge the PR unless the user asks. If they do, use the method the repo expects: the template's top
comment or `AGENTS.md` usually says which (`gh pr merge <n> --merge`, `--rebase`, or `--squash`). If nothing
says, ask instead of picking one.

Report the PR URL, the title, and which template you used. If the template or `AGENTS.md` names a merge
method for this PR, repeat it in the report.
