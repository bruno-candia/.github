#!/usr/bin/env bash
# Adds the review workflow to the repositories named on the command line.
#
#   export JULES_API_KEY=...        # from jules.google.com, Settings, API Key
#   ./scripts/enable.sh portfolio galaxy mcp-hub
#
# The key is read from your environment and handed straight to `gh secret set`.
# Nothing here prints it or writes it to disk.
#
# The workflow file travels over SSH rather than the contents API: writing under
# .github/workflows needs the `workflow` OAuth scope, which the gh token does not
# carry by default, and the API answers 404 instead of saying so. A branch and a
# pull request also mean this works on a repository whose default branch is
# protected, and the pull request itself becomes the first review Jules runs.
set -euo pipefail

: "${JULES_API_KEY:?export JULES_API_KEY before running}"
owner=$(gh api user --jq .login)
workflow=$(cd "$(dirname "$0")/.." && pwd)/examples/pr-review.yml
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for repo in "$@"; do
  echo "== $repo"
  gh secret set JULES_API_KEY --repo "$owner/$repo" --body "$JULES_API_KEY"

  git clone -q --depth 1 "git@github.com:$owner/$repo.git" "$work/$repo"
  cd "$work/$repo"
  mkdir -p .github/workflows
  cp "$workflow" .github/workflows/pr-review.yml

  if git diff --quiet -- .github/workflows/pr-review.yml && ! git status --porcelain | grep -q pr-review; then
    echo "  workflow already there, nothing to do"
    cd - > /dev/null
    continue
  fi

  git checkout -q -b ci/jules-review
  git add .github/workflows/pr-review.yml
  git commit -q -m "ci: review pull requests with Jules"
  git push -q -u origin ci/jules-review
  gh pr create --repo "$owner/$repo" --head ci/jules-review \
    --title "ci: review pull requests with Jules" \
    --body "Calls the shared workflow in bruno-candia/.github. The review on this pull request is the first run." \
    --fill-verbose 2>/dev/null || gh pr create --repo "$owner/$repo" --head ci/jules-review \
    --title "ci: review pull requests with Jules" \
    --body "Calls the shared workflow in bruno-candia/.github. The review on this pull request is the first run."
  cd - > /dev/null
done
