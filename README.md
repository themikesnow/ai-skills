# ai-skills

Single source of truth for AI coding-assistant workflows, shared across
**Claude Code** and **Codex CLI**. The repo owns the files; each tool gets
symlinks pointing back here, so editing a skill once updates both tools.

## Layout

```
ai-skills/
├── README.md
├── install.sh                 # idempotent linker — run to install/update
├── .gitignore
├── skills/
│   ├── change-workflow/       # one folder per skill
│   │   ├── SKILL.md           # canonical instructions
│   │   └── templates/         # files the skill writes from
│   │       ├── design-review.md
│   │       ├── implementation-plan.md
│   │       └── ledger.md
│   └── create-mr/             # open a PR/MR on GitHub or Bitbucket
│       ├── SKILL.md
│       └── scripts/
│           └── create-mr.sh   # push + create PR via the host's API
└── codex/
    └── AGENTS.md              # Codex-only global instructions (no Claude equivalent)
```

## Install

```bash
git clone <your-remote> ~/Documents/development/git/ai-skills
cd ~/Documents/development/git/ai-skills
./install.sh
```

This symlinks:

- every `skills/<name>/` into `~/.claude/skills/<name>` **and** `~/.codex/skills/<name>`
- `codex/AGENTS.md` into `~/.codex/AGENTS.md`

Re-run `./install.sh` any time you add a skill or set up a new machine — it's
idempotent (`ln -sfn`). Use `--dry-run` to preview, `--claude` / `--codex` to
limit to one tool.

Verify what actually loaded:

```bash
codex --print-instructions      # dumps the merged AGENTS.md Codex loaded
# for Claude, check the skill appears in its skill listing
```

## Skill setup

### create-mr

Pushes the current branch and opens a pull request with a title and description
written from the diff. It picks the host from `origin` and reads tokens from the
environment (falling back to `~/.zshrc`):

| Host | Variable | Token |
|---|---|---|
| GitHub | `GITHUB_TOKEN` | Fine-grained token with Contents + Pull requests read/write, or a classic token with `repo` |
| Bitbucket | `BITBUCKET_TOKEN` | Repository/workspace access token (`ATCTT…`) with Repositories + Pull requests write; or an Atlassian API token (`ATATT…`) plus `BITBUCKET_EMAIL` |

Check auth without pushing anything: `skills/create-mr/scripts/create-mr.sh --check`.

## Adding a new skill

1. Create `skills/<new-skill>/SKILL.md` (with `name` + `description`
   frontmatter) and any supporting `templates/` or `references/`.
2. Run `./install.sh`.
3. Commit.

That's it — the installer picks up any folder under `skills/`.

## When Claude and Codex need different skill descriptions

By default a skill's single `SKILL.md` is symlinked to both tools, so they
share one `description`. The body is tool-agnostic; only the triggering
`description` ever really differs. If a specific skill needs per-tool
frontmatter, convert it to the **variant** layout:

```
skills/<name>/
├── variants/
│   ├── body.md        # shared markdown body (no frontmatter)
│   ├── claude.md      # Claude frontmatter block only
│   └── codex.md       # Codex frontmatter block only
└── templates/         # still shared, still symlinked
```

`install.sh` detects `variants/` and **generates** `SKILL.md` per tool
(`claude.md` + `body.md` for Claude, `codex.md` + `body.md` for Codex) instead
of symlinking. Note: generated `SKILL.md` files are build output — they're
gitignored inside `variants/`-based skills, and you re-run `install.sh` after
editing. Only reach for this when a skill's triggering genuinely needs to
diverge; plain symlinks are the default for a reason.

## Notes / gotchas

- **The symlinks are load-bearing.** If either CLI ever ships an updater that
  rewrites a skill folder in place, it could replace a symlink with real files.
  You install by hand here, so this is unlikely — but if a skill mysteriously
  stops tracking the repo, check whether its link got clobbered and re-run
  `install.sh`.
- **`ai-temp/` is runtime state, not repo content.** Skills write their working
  files into an `ai-temp/` directory at the root of whatever project you're
  coding in — change-workflow uses
  `ai-temp/change-workflow/<branch-or-slug>/` for its design review, plan, and
  ledger. That's per-project state, so it belongs in that project's
  `.gitignore`, not here; the skill appends the entry itself the first time it
  creates the directory. One ignore line per repo covers every skill that ever
  writes there.
- **Keep `codex/AGENTS.md` lean** (under ~150 lines). Codex reads it every turn,
  so it's for rules, not lore. Project-level `AGENTS.md` in a given repo
  supersedes this global one where they conflict.
