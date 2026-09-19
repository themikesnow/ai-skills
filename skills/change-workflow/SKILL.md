---
name: change-workflow
description: Enforces a structured clarify -> design -> plan -> execute workflow with a resumable ledger for code changes. Use this skill whenever the user asks to implement a code change, add a feature, refactor code, or fix a bug that touches more than a trivial amount of code (roughly more than ~20 lines or more than one file). Use it even when the user does not explicitly ask for a "plan" or "design" — any non-trivial implementation request should go through this workflow. Do NOT use for one-line edits, typo fixes, formatting-only changes, or pure questions about the code.
---

# Change Workflow

Enforce the phases below in order for any non-trivial code change. Do NOT jump
straight to writing implementation code.

## Where working files live

All working files for one change live in:

```
ai-temp/change-workflow/<change-dir>/
├── design-review.md
├── implementation-plan.md
└── ledger.md
```

`ai-temp/` sits at the project root and is the shared scratch directory for
agent-generated files. `<change-dir>` isolates this change from any other that
is in flight:

- Use the current git branch name, with `/` flattened to `-`
  (`feature/exercise-equipment` -> `feature-exercise-equipment`).
- If there is no branch to key on — detached HEAD, no git repo, or the branch is
  the trunk (`main`/`master`) — use a kebab-case slug of the change goal
  instead (`add-trainer-client-link`).

Create the directories if they do not exist. When first creating `ai-temp/`,
check the project's `.gitignore` for an `ai-temp/` entry and append one if it is
absent. Do not ask permission for this — just state in one line that you did it.

Templates for the three files are in this skill's `templates/` directory — read
the matching template when you need to produce a file.

## Phase 0: Check for an existing ledger

Before anything else, look for existing ledgers under
`ai-temp/change-workflow/`.

- Check this change's own directory first. If its `ledger.md` exists with
  unfinished items (status IN_PROGRESS or BLOCKED, or any unchecked
  pending/in-progress steps), summarize where the last session left off — the
  goal, what's done, and the recorded "Next action" — then ask whether to resume
  or start fresh.
- If sibling directories hold unfinished ledgers for *other* changes, mention
  them in one line so the user knows what else is open, but do not resume them.
- If no ledger exists, or the previous change is DONE, proceed to Phase 1.

## Phase 1: Clarify (efficiently)

Ask ONLY questions whose answers you cannot get by reading the codebase or
inferring from the request. Read the relevant files first; do not ask what you
can discover.

- Batch all questions into a single message. Cap at ~5.
- If requirements are already clear, say so explicitly and skip to Phase 2.
- Cover, only where genuinely ambiguous: scope boundaries, acceptance criteria,
  and constraints (performance, compatibility, dependencies, conventions to
  follow).

## Phase 2: Design review

Write `design-review.md` using `templates/design-review.md`. Cover the approach,
affected components/files, alternatives considered and why rejected, risks and
mitigations, and any open questions.

Pause and get the user's approval before moving to Phase 3.

## Phase 3: Implementation plan

Write `implementation-plan.md` using `templates/implementation-plan.md`. Produce
an ordered checklist of small, independently testable steps, plus how each step
is verified.

## Phase 4: Execute and maintain the ledger

Create/update `ledger.md` using `templates/ledger.md`, then work the plan.

- Mark a step in-progress when you start it, done when it passes verification.
- After completing OR interrupting any step, update the ledger with: what was
  done, files touched, current state, and the single exact next action.
- Keep the ledger current after every step. It must always be complete enough
  that if work stops for any reason, a fresh session can pick up from the
  ledger alone with no lost context.

## Escape hatch for small changes

If the change turns out to be under ~20 lines and confined to one file,
collapse Phases 2–4 into a single short summary (approach + steps) and proceed,
without writing the separate design-review and implementation-plan files. Still
keep a minimal ledger if the work spans more than one session.

## Cleanup

Once a change's ledger is DONE and the work is merged, its
`ai-temp/change-workflow/<change-dir>/` directory can be deleted. Offer this
when you finish a change, so `ai-temp/` does not accumulate stale state.
