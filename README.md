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
| `release` | project | Git-flow release: branch from `develop`, changelog, PR into `main` with a merge commit, tag, GitHub release, back-merge into `develop`. Also hotfixes |

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
npx skills add iagolaguna/ars-agent-skills --skill worktree -g
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
