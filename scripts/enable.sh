#!/usr/bin/env bash
# Adds the review workflow to the repositories named on the command line.
#
#   export JULES_API_KEY=...        # from jules.google.com, Settings, API Key
#   ./scripts/enable.sh portfolio galaxy mcp-hub
#
# The key is read from your environment and handed straight to `gh secret set`.
# Nothing here prints it or writes it to disk.
set -euo pipefail

: "${JULES_API_KEY:?export JULES_API_KEY before running}"
owner=$(gh api user --jq .login)
workflow=$(dirname "$0")/../examples/pr-review.yml

for repo in "$@"; do
  printf '%s: ' "$repo"
  gh secret set JULES_API_KEY --repo "$owner/$repo" --body "$JULES_API_KEY"
  branch=$(gh repo view "$owner/$repo" --json defaultBranchRef --jq .defaultBranchRef.name)
  sha=$(gh api "repos/$owner/$repo/contents/.github/workflows/pr-review.yml?ref=$branch" --jq .sha 2>/dev/null || true)
  args=(-f "message=ci: review pull requests with Jules"
        -f "content=$(base64 < "$workflow" | tr -d '\n')"
        -f "branch=$branch")
  [ -n "$sha" ] && args+=(-f "sha=$sha")
  gh api -X PUT "repos/$owner/$repo/contents/.github/workflows/pr-review.yml" "${args[@]}" --jq '.commit.sha' > /dev/null
  echo "workflow committed to $branch"
done
