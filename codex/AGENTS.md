# Working agreements

## Non-trivial code changes: clarify -> design -> plan -> execute

For any request to implement a code change, add a feature, refactor, or fix a
bug that touches more than ~20 lines or more than one file, follow this
workflow. Do NOT jump straight to writing implementation code. (One-line edits,
typo fixes, and formatting-only changes skip this.)

Working files for one change live in `ai-temp/change-workflow/<change-dir>/` at
the project root — `ai-temp/` is the shared scratch directory for
agent-generated files. `<change-dir>` is the current git branch with `/`
flattened to `-`, or a kebab slug of the change goal when there is no branch to
key on (detached HEAD, no repo, or the trunk branch). Create the directories if
needed; when first creating `ai-temp/`, append `ai-temp/` to the project's
`.gitignore` if absent and say so in one line rather than asking.

Templates are in `~/.codex/skills/change-workflow/templates/`.

0. Check for existing ledgers under `ai-temp/change-workflow/` first. If this
   change's `ledger.md` exists with unfinished work, summarize the goal, what's
   done, and the recorded "Next action", then ask whether to resume or start
   fresh. Mention unfinished ledgers in sibling directories in one line, but do
   not resume them.

1. Clarify efficiently. Ask only what you cannot get by reading the codebase.
   Batch questions into one message, cap at ~5. If requirements are already
   clear, say so and continue. Cover scope, acceptance criteria, and
   constraints only where genuinely ambiguous.

2. Write `design-review.md` (see template): approach, affected files,
   alternatives considered and why rejected, risks, open questions. Pause for
   approval.

3. Write `implementation-plan.md` (see template): an ordered checklist of small,
   independently testable steps, plus how each is verified.

4. Execute the plan and keep `ledger.md` current (see template). Mark steps
   in-progress when started, done when they pass. After completing OR
   interrupting any step, record what was done, files touched, current state,
   and the single exact next action. The ledger must always be complete enough
   that a fresh session can resume from it alone.

Escape hatch: if the change is under ~20 lines in one file, collapse steps 2-4
into a short summary and proceed.

Cleanup: once a change's ledger is DONE and the work is merged, offer to delete
its `ai-temp/change-workflow/<change-dir>/` directory so scratch state does not
accumulate.

<!--
  This file is the source of truth for Codex global instructions.
  It is symlinked to ~/.codex/AGENTS.md by install.sh.
  Keep it under ~150 lines: Codex reads it every turn.
  Add further global working agreements below as they accrue.
-->
