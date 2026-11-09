# ars-agent-skills

My agent skills and the OpenSpec setup I use to start new projects. They work with any agent that reads the [Agent Skills](https://agentskills.io) format, not just Claude Code: Codex, Cursor, Gemini CLI, OpenCode, Grok and the rest.

*Ars* is Latin for craft, the know-how of a trade. That's what this repo holds.

## Two levels

```
skills/
  global/     skills that make sense in any repo
  project/    skills that live inside a project's repo
templates/
  github/     PR templates the project skills rely on
  openspec/   base config.yaml for OpenSpec
```

Global skills go in `~/.agents/skills`. Project skills get copied into the project's `.agents/skills`, so they're versioned with the code and anyone who clones the repo gets them.

`.agents/skills` is the canonical place. Grok, Codex, Cursor and most other agents read it directly, both in `~` and in the project. Claude Code is the exception: it only reads `.claude/skills`, so the installer symlinks each skill there. Every skill keeps one real copy.

## Skills

| Skill | Level | What it does |
|-------|-------|--------------|
| `commit` | project | Groups changes and commits them in English with conventional commits |
| `open-pr` | project | Writes the PR title and body from the repo's own template, creates or updates the PR |
| `worktree` | global | Creates or removes a git worktree off the default branch, copying untracked `.env*` files and installing deps |
| `typescript` | global | TS/JS style: named and derived types, pure functions, guard clauses, exhaustive pattern matching, typed errors, few comments, no one-call wrappers |
| `frontend` | global | React and Next.js client code: named props, derived state, effects only for external systems, UI states as unions, accessible markup. Builds on `typescript` |
| `backend` | global | Node.js and Next.js server code: parse at the edge, pure domain logic with injected deps, typed errors mapped to HTTP in one place, typed config, structured logs. Builds on `typescript` |
| `release` | project | Git-flow release: branch from `develop`, changelog, PR into `main` with a merge commit, tag, GitHub release, back-merge into `develop`. Also hotfixes |

`typescript`, `frontend` and `backend` are meant to load together: the last two only add what's specific to their side and point back to `typescript` for the language rules. All three defer to decisions the project already made (lint config, `neverthrow`, `ts-pattern`) and tell the agent to check a library's docs through [Context7](https://context7.com) before writing against an API it isn't sure about for the installed version, so they work best with the Context7 MCP server set up.

Project skills don't hardcode a project's checks. `release` runs whatever the project's `AGENTS.md` lists as required before a PR, so the same SKILL.md works in every repo.

## Install

```bash
git clone https://github.com/iagolaguna/ars-agent-skills.git
cd ars-agent-skills

./install.sh global                   # symlinks into ~/.agents/skills
./install.sh project ~/code/my-app    # copies into my-app/.agents/skills
./install.sh diff ~/code/my-app       # shows where my-app's copies drifted from this repo
```

Existing skills with the same name are never overwritten. The installer prints `skip` and moves on. `project` also adds `.github/PULL_REQUEST_TEMPLATE/release.md` when the project doesn't have one.

Project skills are copies, so they drift when someone improves them inside a project. Run `diff` before reinstalling or after a project changes its copy, and bring the generic part of the change back here.

If you'd rather use the [skills CLI](https://github.com/vercel-labs/skills), it finds everything under `skills/`:

```bash
npx skills add iagolaguna/ars-agent-skills --skill worktree typescript frontend backend -g
npx skills add iagolaguna/ars-agent-skills --skill commit open-pr release
```

It won't set up OpenSpec, though.

## OpenSpec

`./install.sh project` also sets up [OpenSpec](https://github.com/Fission-AI/OpenSpec) when the CLI is installed:

1. Copies `templates/openspec/config.yaml` into `openspec/` if the project doesn't have one yet.
2. Runs `openspec init --tools claude,agents`, which writes the OpenSpec skills to `.claude/skills` and `.agents/skills`. Claude also gets the `/opsx:*` commands. Other agents call the skills by name, like `/openspec-propose`.

The OpenSpec skills themselves aren't in this repo. The CLI generates them, and `openspec update` keeps both copies in sync.

The template is where my workflow lives. Its `context` block holds what an agent can't learn from reading the code: what the product promises, the invariants that can't bend, and what's out of scope. The `rules` block adds checks per artifact, so a proposal has to say which invariants it touches and the task list always ends with the project's checks. Stack and commands stay in `AGENTS.md`.

## License

MIT
