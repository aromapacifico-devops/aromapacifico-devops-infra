#!/usr/bin/env bash
# Creates or updates the pull request comment that starts with the marker of a file.
# usage: comment.sh FILE. Needs GH_TOKEN, GITHUB_REPOSITORY and PR_NUMBER.
set -euo pipefail

file=$1
marker=$(head -1 "$file")
body=$(head -c 60000 "$file")
id=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" \
  --jq ".[] | select(.user.login == \"github-actions[bot]\" and (.body | startswith(\"$marker\"))) | .id" | head -1)
if [ -n "$id" ]; then
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$id" -f body="$body" --silent
else
  gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" -f body="$body" --silent
fi
