---
title: Type a bare dartway, and format with dartway format
affects:
  dartway_cli: "0.26.0-dev.1"
---

## Who is affected

Every project. Two kinds of standing rule exist only because the tools did not pick the project's
own versions, and they can now go:

- "run `dart run dartway_cli:dartway <command>`, never a bare `dartway`" — a `dartway` of another
  version now runs the CLI the project pins instead of refusing;
- "format with the Dart the pin carries (`.fvmrc`), and only your own files" — `dartway format` does
  exactly that.

## What to change

1. Update the global CLI, so that the `dartway` on the `PATH` is one that hands project commands
   over (an older global CLI still refuses them):

       dart pub global activate --source git https://github.com/dartway/dartway --git-path packages/dartway_cli --git-ref stable

   Machines and agent sandboxes without a global CLI keep working with
   `dart run dartway_cli:dartway <command>` from the Flutter package.
2. Delete both rules from the project's `AGENTS.md` / `CLAUDE.md` (and any other instruction file
   that repeats them). Format with `dartway format`; the toolkit's `dartway-finish` does.
3. Add the format gate to `.github/workflows/ci.yml`, after `generate --check`, as the skeleton has
   it (it needs the `CONTRACT_BASE` the contract checks already resolve):

       - name: format --check
         if: ${{ !cancelled() && steps.deps.outcome == 'success' }}
         working-directory: <project>_flutter
         run: dart run dartway_cli:dartway format --check --base "$CONTRACT_BASE"

## How to check

From the project root, with a global `dartway` of any other version: `dartway check` prints
`running the dartway_cli <version> this project pins` and runs. `dartway format --check` passes on a
branch whose changed files are formatted, and names the Dart it used.
