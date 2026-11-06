# ars-agent-skills

My agent skills and the OpenSpec setup I use to start new projects. They work with any agent that reads the [Agent Skills](https://agentskills.io) format, not just Claude Code: Codex, Cursor, Gemini CLI, OpenCode, Grok and the rest.

*Ars* is Latin for craft, the know-how of a trade. That's what this repo holds.

## Two levels

```
skills/
  global/     skills that make sense in any repo
  project/    skills that live inside a project's repo
templates/
  openspec/   base config.yaml for OpenSpec
```

Global skills go in `~/.agents/skills`. Project skills get copied into the project's `.agents/skills`, so they're versioned with the code and anyone who clones the repo gets them.

`.agents/skills` is the canonical place. Most agents read it directly. Two don't: Claude Code only reads `.claude/skills`, and Grok only reads `.grok/skills` inside a project (it does read `~/.agents/skills` globally). The installer creates symlinks for both, so every skill has one real copy.

## Skills

| Skill | Level | What it does |
|-------|-------|--------------|
| `commit` | global | Groups changes and commits them in English with conventional commits |
| `open-pr` | global | Writes the PR title and body from the repo's own template, creates or updates the PR |
| `worktree` | global | Creates or removes a git worktree, copying `.env*` files and installing deps |
| `release` | project | Cuts a version from a release branch: changelog, PR to `main`, tag, GitHub release, backport to `develop` |

## Install

```bash
git clone https://github.com/iagolaguna/ars-agent-skills.git
cd ars-agent-skills

./install.sh global                   # symlinks into ~/.agents/skills
./install.sh project ~/code/my-app    # copies into my-app/.agents/skills
```

Existing skills with the same name are never overwritten. The installer prints `skip` and moves on.

If you'd rather use the [skills CLI](https://github.com/vercel-labs/skills), it finds everything under `skills/`:

```bash
npx skills add iagolaguna/ars-agent-skills --skill commit open-pr worktree -g
npx skills add iagolaguna/ars-agent-skills --skill release
```

It won't create the Grok mirror or set up OpenSpec, though.

## OpenSpec

`./install.sh project` also sets up [OpenSpec](https://github.com/Fission-AI/OpenSpec) when the CLI is installed:

1. Copies `templates/openspec/config.yaml` into `openspec/` if the project doesn't have one yet.
2. Runs `openspec init --tools claude,agents,grok`, which writes the OpenSpec skills to `.claude/skills`, `.agents/skills` and `.grok/skills`. Claude also gets the `/opsx:*` commands. Other agents call the skills by name, like `/openspec-propose`.

The OpenSpec skills themselves aren't in this repo. The CLI generates them, and `openspec update` keeps all three copies in sync.

The template is where my workflow lives. Its `context` block holds what an agent can't learn from reading the code: what the product promises, the invariants that can't bend, and what's out of scope. The `rules` block adds checks per artifact, so a proposal has to say which invariants it touches and the task list always ends with the project's checks. Stack and commands stay in `AGENTS.md`.

## License

MIT
