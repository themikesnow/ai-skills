---
name: create-mr
description: Create a merge request / pull request for the current branch on GitHub or Bitbucket, with a descriptive title and description written from the actual changes. Use when the user asks to create, open or raise an MR or PR, or to push their branch for review.
---

# Create an MR / PR

Works for GitHub (`github.com`) and Bitbucket Cloud (`bitbucket.org`) remotes. The helper script,
`scripts/create-mr.sh` in this skill's folder (written `<skill-dir>` below),
detects the host from `origin`, uses the right token and API, pushes the branch, and opens the
PR (or returns the one already open for the branch).

## Auth

The script reads these from the environment, falling back to the user's interactive zsh
profile (`~/.zshrc`), so they do not need to be exported to this shell:

| Host | Variables | How they are used |
|---|---|---|
| GitHub | `GITHUB_TOKEN` | `Authorization: Bearer`; git user `x-access-token` |
| Bitbucket, access token (`ATCTT…`) | `BITBUCKET_TOKEN` (repository/workspace/project access token) | `Authorization: Bearer`; git user `x-token-auth` |
| Bitbucket, API token (`ATATT…`) | `BITBUCKET_TOKEN` + `BITBUCKET_EMAIL` (Atlassian account email; falls back to `git config user.email`) | API: basic auth `email:token`; git user `x-bitbucket-api-token-auth` |

Never print, echo or log a token, and never put one in a remote URL or a command argument. If a
variable is missing or the API answers 401/403/404, stop and tell the user which variable or
token scope to fix; do not retry with other auth schemes. The script picks the Bitbucket scheme
from the token's prefix. Bitbucket tokens need repository write and pull request write scopes, and an
access token only works for the repository, project or workspace it was created in.

## Steps

1. **Inspect the state.** Run `git status`, `git branch --show-current`, `git remote get-url origin`,
   and find the base branch (the repo's default, usually `main`/`master`, unless the user names one).
2. **Branch if needed.** If on the base branch with changes to submit, create a branch named for the
   change (`feat/...`, `fix/...`, `chore/...`, `docs/...`, `refactor/...`). If there are uncommitted
   changes, commit them only when the user asked for that or asked to "create the MR" for work that
   is clearly theirs to submit; follow the repo's commit-message style (`git log --oneline -10`).
3. **Understand the changes.** Read what the MR will contain, not just file names:
   `git log --oneline <base>..HEAD` and `git diff <base>...HEAD` (use `--stat` first on large diffs,
   then read the important hunks). Note what changed, why, and anything a reviewer must know.
4. **Write the title.** Imperative, specific, under ~72 characters, in the repo's convention
   (e.g. Conventional Commits `feat: ...` if the history uses it). It should say what the MR does,
   e.g. `feat: add mise support and upgrade to Node 26`, never `Update files` or the branch name.
5. **Write the description** in Markdown, to a temp file (e.g. `mktemp`):
   - `## Summary`: one or two sentences on what and why.
   - `## Changes`: bullets grouped by area, each saying what changed and why it matters.
   - `## Testing`: what was actually run and its result; say plainly what was not run or fails.
   - `## Notes` (only if needed): breaking changes, follow-ups, known issues, deploy steps.
   - End with any attribution lines the session's instructions require for PR descriptions.
   Describe only what the diff contains; do not invent tests or results.
6. **Create it:**
   ```bash
   <skill-dir>/scripts/create-mr.sh --title "<title>" --body-file <file> [--base <branch>] [--draft]
   ```
   Run with `--check` first to verify auth and the base branch without pushing anything.
   The last line printed is the PR URL. If a PR was already open for the branch, the script says so
   and prints its URL; update it only if the user asks.
7. **Report** the title and the URL. If a `link_pull_request` tool is available, call it with the URL.
