# Documentation

- **`1_general/`** — architecture and infrastructure of this project, plus the
  cross-cutting references that have no feature of their own: an analytics event
  registry, a settings-key catalog, an access matrix, the payload of an external
  integration. The mark of one: it describes an agreement that holds across the
  whole app, not a screen.
- **`audits/`** — reports produced by `/dartway-audit`.

**There is no doc-per-feature here, on purpose.** A feature is described where
it lives: `DwFeatureSpec` in its public file says what it does, what to expect
and where the traps are, `knownIssues` in the same spec says what is wrong with
it, and doc comments above the `DwCrudConfig` carry the server-side rules.

A description kept away from the code drifts from it silently — the compiler
does not check it, the checker cannot see it, and the next agent reads it and
believes it. A spec in the feature's own file survives an edit because it sits
in the same diff.

If you feel like adding a file here named after a feature, don't: it means the
description did not fit in the spec, and the question is why the spec is not
answering.

The DartWay methodology itself lives in `.claude/` (CLAUDE.md + skills).
