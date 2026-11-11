#!/usr/bin/env bash
# Push the current branch and open a pull request on GitHub or Bitbucket Cloud.
#
# Usage: create-mr.sh --title "<title>" --body-file <file> [--base <branch>] [--draft]
#        create-mr.sh --check   (verify auth and base branch only; pushes and creates nothing)
#
# Auth (read from the environment; if unset, from an interactive zsh profile):
#   GitHub:    GITHUB_TOKEN                      (Bearer token; git user x-access-token)
#   Bitbucket: BITBUCKET_TOKEN, either a repository/workspace access token (ATCTT..., Bearer) or an
#              Atlassian API token (ATATT..., needs BITBUCKET_EMAIL, falling back to git user.email)
#
# Prints the PR URL on the last line. If an open PR already exists for the branch, prints its URL.
set -euo pipefail

title="" body_file="" base="" draft=false check=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --draft) draft=true; shift ;;
    --check) check=true; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
$check || [[ -n "$title" && -f "$body_file" ]] || { echo "need --title and an existing --body-file" >&2; exit 2; }

die() { echo "error: $*" >&2; exit 1; }

# Read a variable from the environment, or from the user's interactive zsh profile.
from_env() {
  local name="$1" val="${!1:-}"
  if [[ -z "$val" ]] && command -v zsh >/dev/null; then
    val="$(zsh -ic "printf %s \"\${$name:-}\"" 2>/dev/null || true)"
  fi
  printf %s "$val"
}

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" != "HEAD" ]] || die "detached HEAD; check out a branch first"
remote_url="$(git remote get-url origin)"

# Parse host/owner/repo from https or ssh remotes.
path="$(printf %s "$remote_url" | sed -E 's#^(https?://([^@/]+@)?|git@|ssh://git@)##; s#:#/#; s#\.git$##')"
host="${path%%/*}"; rest="${path#*/}"; owner="${rest%%/*}"; repo="${rest#*/}"
[[ -n "$owner" && -n "$repo" ]] || die "could not parse owner/repo from $remote_url"


case "$host" in
  github.com)
    token="$(from_env GITHUB_TOKEN)"; [[ -n "$token" ]] || die "GITHUB_TOKEN is not set"
    api="https://api.github.com/repos/$owner/$repo"
    auth=(-H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json")
    if [[ -z "$base" ]]; then
      base="$(curl -fsS "${auth[@]}" "$api" | python3 -c 'import json,sys; print(json.load(sys.stdin)["default_branch"])')"
    fi
    if $check; then echo "ok: github $owner/$repo, branch $branch -> $base"; exit 0; fi
    [[ "$branch" != "$base" ]] || die "on the base branch '$base'; create a feature branch first"

    TOKEN="$token" git -c credential.helper= \
      -c 'credential.helper=!f() { echo username=x-access-token; echo "password=$TOKEN"; }; f' \
      push -u origin "$branch" >&2

    existing="$(curl -fsS "${auth[@]}" "$api/pulls?state=open&head=$owner:$branch" \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["html_url"] if d else "")')"
    if [[ -n "$existing" ]]; then echo "PR already open:"; echo "$existing"; exit 0; fi

    payload="$(python3 - "$title" "$body_file" "$branch" "$base" "$draft" <<'PY'
import json, sys
title, body_file, head, base, draft = sys.argv[1:]
print(json.dumps({"title": title, "body": open(body_file).read(), "head": head, "base": base,
                  "draft": draft == "true"}))
PY
)"
    resp="$(curl -sS -w '\n%{http_code}' "${auth[@]}" -X POST "$api/pulls" -d "$payload")"
    code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
    [[ "$code" == 201 ]] || die "GitHub returned $code: $body"
    printf %s "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])'
    ;;

  bitbucket.org)
    token="$(from_env BITBUCKET_TOKEN)"; [[ -n "$token" ]] || die "BITBUCKET_TOKEN is not set"
    api="https://api.bitbucket.org/2.0/repositories/$owner/$repo"
    # Two token kinds, told apart by prefix. The token is passed to curl through a config on stdin,
    # so it never appears in the process list.
    #   ATCTT...: repository/workspace/project access token -> Bearer; git user x-token-auth
    #   ATATT...: Atlassian API token -> basic auth email:token; git user x-bitbucket-api-token-auth
    if [[ "$token" == ATATT* ]]; then
      email="$(from_env BITBUCKET_EMAIL)"; [[ -n "$email" ]] || email="$(git config user.email || true)"
      [[ -n "$email" ]] || die "set BITBUCKET_EMAIL to your Atlassian account email"
      git_user="x-bitbucket-api-token-auth"
      bb() { printf 'user = "%s:%s"\n' "$email" "$token" | curl -sS -K - "$@"; }
      hint="check BITBUCKET_EMAIL is your Atlassian account email and the API token has repository and pull request scopes"
    else
      git_user="x-token-auth"
      bb() { printf 'header = "Authorization: Bearer %s"\n' "$token" | curl -sS -K - "$@"; }
      hint="the access token must belong to this repository (or its workspace/project) and have repository write + pull request write scopes"
    fi

    repo_code="$(bb -o /dev/null -w '%{http_code}' "$api")"
    [[ "$repo_code" == 200 ]] || die "Bitbucket API returned $repo_code for $owner/$repo ($hint)"
    if [[ -z "$base" ]]; then
      base="$(bb "$api" | python3 -c 'import json,sys; print(json.load(sys.stdin)["mainbranch"]["name"])')"
    fi
    if $check; then echo "ok: bitbucket $owner/$repo, branch $branch -> $base"; exit 0; fi
    [[ "$branch" != "$base" ]] || die "on the base branch '$base'; create a feature branch first"

    TOKEN="$token" GIT_USER="$git_user" git -c credential.helper= \
      -c 'credential.helper=!f() { echo "username=$GIT_USER"; echo "password=$TOKEN"; }; f' \
      push "https://$git_user@bitbucket.org/$owner/$repo.git" "$branch" >&2
    # Pushed to an explicit URL (so the token's git user is used); track origin, not that URL.
    git config "branch.$branch.remote" origin
    git config "branch.$branch.merge" "refs/heads/$branch"

    q="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "source.branch.name=\"$branch\" AND state=\"OPEN\"")"
    existing="$(bb "$api/pullrequests?q=$q" | python3 -c 'import json,sys; v=json.load(sys.stdin).get("values",[]); print(v[0]["links"]["html"]["href"] if v else "")')"
    if [[ -n "$existing" ]]; then echo "PR already open:"; echo "$existing"; exit 0; fi

    payload="$(python3 - "$title" "$body_file" "$branch" "$base" "$draft" <<'PY'
import json, sys
title, body_file, head, base, draft = sys.argv[1:]
print(json.dumps({"title": title, "description": open(body_file).read(),
                  "source": {"branch": {"name": head}}, "destination": {"branch": {"name": base}},
                  "close_source_branch": True, "draft": draft == "true"}))
PY
)"
    resp="$(bb -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' "$api/pullrequests" -d "$payload")"
    code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
    [[ "$code" == 201 ]] || die "Bitbucket returned $code: $body"
    printf %s "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin)["links"]["html"]["href"])'
    ;;

  *) die "unsupported host '$host' (only github.com and bitbucket.org)" ;;
esac
