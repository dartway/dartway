---
title: Consolidate agent skills and root instructions
affects:
  dartway_cli: "0.26.0"
---

## Who is affected

Projects with an installed DartWay agent toolkit, especially custom skills under
`.claude/skills/` or project rules maintained in both root instruction files.

## What to change

1. Run `dartway update --plan`, then install its exact target with `dartway update
   --target <sha>` using the same source options. Skills are installed once in
   `.agents/skills/`; `.claude/skills` becomes the relative symlink
   `../.agents/skills` when Claude is selected. Claude-only custom skills move
   into the shared directory. Equal custom copies collapse. If custom copies
   differ, installation names the conflicting skill and changes nothing: resolve
   those copies yourself, then repeat the update. Managed `dartway-*` copies are replaced.
2. Move project rules from root `CLAUDE.md` into root `AGENTS.md`, resolving
   contradictions yourself, and replace root `CLAUDE.md` with `@AGENTS.md`.
   `dartway check` warns as `instructionsDuplicated` until this is done.
   The installer preserves owner text and does not perform this merge.
3. Commit `.agents/`, the `.claude/skills` symlink, `.claude/CLAUDE.md` and the root
   instruction files. Remove previously tracked duplicate skill files from Git
   when staging the migration. Keep symlinks enabled in checkouts used by Claude.
4. For unattended executors, run `dartway setup-ai --no-interactive` with your
   usual source options, or set the top-level `interactive` boolean in
   `.agents/dartway-toolkit.json` to `false`. Managed steps that need a human
   answer put their proposal in the final report and stop that step. They never
   publish or apply unconfirmed actions. Independent authorized work continues.
   Omitted `interactive` means `true`; later updates preserve the choice.

Verify both discovery paths reach the same `SKILL.md`, and run the project's
checks. Record this note's disposition only after reviewing the owner text merge
and the installed layout.
