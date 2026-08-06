#!/usr/bin/env bash
# Turns on Jules review for the repositories named on the command line.
#
#   export JULES_API_KEY=...        # from jules.google.com, Settings, API Key
#   ./enable.sh portfolio galaxy mcp-hub
#
# Self contained on purpose: download this one file anywhere and run it. It
# carries the caller workflow inline, so there is nothing to clone and no
# sibling file to be missing.
#
# The key is read from the environment and handed straight to `gh secret set`.
# Nothing here prints it or writes it to disk.
#
# The workflow travels over SSH rather than the contents API: writing under
# .github/workflows needs the `workflow` OAuth scope, which the gh token does
# not carry by default, and the API answers 404 instead of saying so. Going
# through a branch and a pull request also survives a protected default branch,
# and that pull request becomes the first review Jules runs.
set -euo pipefail

: "${JULES_API_KEY:?export JULES_API_KEY before running}"
[ $# -gt 0 ] || { echo "usage: $0 <repo> [repo...]" >&2; exit 1; }

owner=$(gh api user --jq .login)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/pr-review.yml" <<'YAML'
name: Pull request review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

jobs:
  jules:
    uses: bruno-candia/.github/.github/workflows/jules-review.yml@main
    secrets:
      JULES_API_KEY: ${{ secrets.JULES_API_KEY }}
YAML

for repo in "$@"; do
  echo "== $repo"
  gh secret set JULES_API_KEY --repo "$owner/$repo" --body "$JULES_API_KEY"

  git clone -q --depth 1 "git@github.com:$owner/$repo.git" "$work/$repo"
  cd "$work/$repo"
  mkdir -p .github/workflows
  cp "$work/pr-review.yml" .github/workflows/pr-review.yml

  if [ -z "$(git status --porcelain .github/workflows/pr-review.yml)" ]; then
    echo "  workflow already there, nothing to do"
    cd "$work"
    continue
  fi

  git checkout -q -b ci/jules-review
  git add .github/workflows/pr-review.yml
  git commit -q -m "ci: review pull requests with Jules"
  git push -q -u origin ci/jules-review
  gh pr create --repo "$owner/$repo" --head ci/jules-review \
    --title "ci: review pull requests with Jules" \
    --body "Calls the shared workflow in bruno-candia/.github. The review on this pull request is the first run."
  cd "$work"
done
