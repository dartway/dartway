# DartWay Claude Toolkit

The Claude Code harness for DartWay apps: reusable `dartway-*` skills and commands, installed into
a project's `.claude/` by `dartway create` / `dartway setup-ai` / `dartway update`. **The single
source of truth is this folder** — the skills are versioned and evolve together with the framework
code, in the same pull request as the API change they teach (see the monorepo's root `CLAUDE.md`).

What gets installed, how it is kept in sync, the `__*__` tokens, the managed-files rule and
`.claude/settings.json`'s merge behaviour: [What is the `.claude/` folder in a DartWay
project?](https://dartway.dev/5-tooling/agent-toolkit) This file covers only what that page does
not: developing the toolkit itself.

## Developing the toolkit

Edit the skills **here** and push. For a fast edit→test cycle, install into a real project from a
local checkout:

```bash
dartway setup-ai --local-repo ../dartway    # or DARTWAY_MONOREPO_DIR=../dartway
```

Edit → re-run `setup-ai` in the project → test → `git push`. There is no reverse sync: the source of
truth is always here.

**The invariant: `CLAUDE.md`, `skills/` and `commands/` must contain no project literals — only
`__*__` tokens.** These files land in the `.claude/` of every project on the framework, so a role
name, a package name or a domain lifted from the project you were looking at while writing arrives
in all of them.

Nothing greps for it. A pattern can only list the projects we already know, which is the one set of
names a fresh leak will not come from. Read your own diff instead: a name that means something in
exactly one project is either a token or an invented example.
