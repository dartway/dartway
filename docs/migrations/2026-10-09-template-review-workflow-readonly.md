---
title: The Claude review workflow must not be able to push
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

A project that has `.github/workflows/claude-review.yml` — every project created before
`dartway_cli` 0.24.0 keeps the file unless its owner deleted it. As created, the review step runs
`anthropics/claude-code-action` with `track_progress: true` and no `github_token`: the action
exchanges OIDC for the Claude App's installation token, which can write contents whatever
`permissions:` says, and tracking forces tag mode, whose tools edit and commit. A review run can
push commits to the pull request it reviews.

A project without the file does nothing.

## What to change

In `.github/workflows/claude-review.yml`, in the `with:` of the `anthropics/claude-code-action`
step:

1. Add `github_token: ${{ secrets.GITHUB_TOKEN }}` beside `claude_code_oauth_token`. The workflow's
   own token is held to the `contents: read` the workflow already declares, so GitHub refuses a
   push; `pull-requests: write` and `issues: write` still cover the review comments.
2. Delete the `track_progress: true` line. With an explicit `prompt` and no tracking the action
   runs in agent mode.
3. Add a line to `claude_args`, after `--allowedTools`:

   ```yaml
   --disallowedTools "Edit,Write,MultiEdit,NotebookEdit,Bash(git commit:*),Bash(git push:*)"
   ```

   `--allowedTools` only adds to the toolset; this takes the edit and commit tools away even if a
   later action version grants them by default.

The comment block above the step in the framework's template explains the three locks and can be
copied with them.

## How to check

`grep -nE '^\s*track_progress:' .github/workflows/claude-review.yml` finds nothing, and the file
contains `github_token: ${{ secrets.GITHUB_TOKEN }}` and a `--disallowedTools` line naming
`Bash(git push:*)`. The next pull request's review still posts its comments.
