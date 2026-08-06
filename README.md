# .github

Shared automation for the repositories on this account.

## Jules review

`.github/workflows/jules-review.yml` reviews a pull request with the Jules API
and posts the result as a single comment, replacing it on every new push.

Jules is an agent that edits code, so the prompt is explicit that a review run
reports and changes nothing. The session runs against the pull request branch
with no automation mode, which is what stops it opening a pull request of its
own.

### Turning it on for a repository

1. Connect the repository at [jules.google.com](https://jules.google.com) so it
   shows up under Codebases. The workflow fails with a clear message otherwise.
2. Add a `JULES_API_KEY` secret to the repository, from Jules Settings, API Key.
3. Copy `examples/pr-review.yml` to `.github/workflows/pr-review.yml`.

### Cost

One Jules session per push to an open pull request. The Pro plan allows 100
sessions a day.

### What it will not do

Pull requests from forks are skipped. They carry no secrets, and running them
would mean handing the key to code from outside the account.
