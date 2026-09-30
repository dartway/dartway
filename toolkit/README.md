# DartWay Claude Toolkit

The Claude Code harness for DartWay apps — `CLAUDE.md`, the `dartway-*` skills, the commands and the
`docs/dev_notes/` form — installed into a project's `.claude/` by `dartway create` / `setup-ai` /
`update`. **This folder is the single source**: a skill changes in the same pull request as the API it
teaches. What gets installed and how: [the agent toolkit
page](https://dartway.dev/5-tooling/agent-toolkit).

## Developing the toolkit

Change it here, re-install into a real project from the local checkout —
`dartway setup-ai --local-repo ../dartway` (or `DARTWAY_MONOREPO_DIR=../dartway`) — and test there. There
is no reverse sync.

**How it is written:** a rule is stated once, in the skill that owns its topic; everywhere else points
to it. A rule the checker holds is one row of the law table in `CLAUDE.md` naming the check — the
check's message carries the fix. No history or "why" narratives: they live in
`docs/1.0/DECISIONS.md`, and a skill may cite a D-number. A long sample links the real file in
`example/` or `template/`; `docs_paths_test.dart` fails on a path that does not resolve.

**No project literals — only `__*__` tokens.** These files land in every project; read your own diff
for a name that means something in exactly one of them.
