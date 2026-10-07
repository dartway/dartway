---
name: dartway-documentation
description: >-
  Where a DartWay project's descriptions live and where a finding goes: behaviour in DwFeatureSpec,
  a DTO's meaning above the DTO, a handler's rule above the handler, a registry as an enum;
  `docs/adr/` for decisions and the alternatives they ruled out; `docs/dev_notes/` for findings
  with no address in code. Use before writing any documentation, a DwFeatureSpec, knownIssues, an
  ADR or a dev note, and when deciding where a finding goes.
---

# DartWay — documentation lives in the code (`dartway-documentation`)

**There are no per-feature docs.** A description beside the code changes in the same diff; one apart
from it drifts silently, and the next agent believes it.

| What | Where |
|---|---|
| what a feature does, its traps, what is wrong with it | its `DwFeatureSpec` (`knownIssues` for what is wrong) — fields in `dartway-feature-scaffold` |
| what a DTO, a field, a refusal code or a channel kind means | the doc comment above it in `__SHARED_PKG__` |
| who may call a handler, what it changes and publishes | the doc comment above the handler; above the channel, upload or access rule for theirs |
| a cross-cutting registry — analytics events, settings keys, roles | an enum with doc comments (`__SHARED_PKG__` when both sides use it, the app's `lib/core/` otherwise) |
| an integration's payload | the doc comment on its `DwHttpRoute` |
| how the app is built | the skills; a copy in the project only falls behind |

All of it is written in the project's language (`docCommentLanguage` warns on a doc comment in another
script).

Before writing a document, name what it would say that a spec, a doc comment or code cannot. Usually
the spec is silent where it should not be, and the fix is there.

## `docs/adr/` — decisions and what they ruled out

An ADR exists for **the rejected alternatives**: a rejected option has no code to sit next to. Admission
test: is there an alternative someone will propose again in six months? `docs/adr/NNNN-slug.md`, in the
project's language, with **Status** (`accepted` / `superseded by NNNN`, dated), **Context**,
**Decision**, **Rejected alternatives, each with its reason**, **Limitations accepted knowingly**.
Never "how it works now". An ADR is superseded by a new one, never edited — a default a project may
replace in its root instruction file (`AGENTS.md` or `CLAUDE.md`); check there before opening a number. `dartway-plan` reads them.

## Where a finding goes

Every finding has exactly one home; the first line that fits wins:

| The finding… | Goes to |
|---|---|
| is being fixed in this task | fix it — no entry |
| belongs to one feature | a line in that feature's `knownIssues`, deleted when fixed |
| is about the framework (a missing or vague rule, an API that forced a workaround) | an issue in `__NOTES_TRACKER__` — `dartway-framework-notes` |
| has no address in code — cross-cutting, infrastructural, a decision with a price | a file in `docs/dev_notes/` — the form is `docs/dev_notes/README.md` |

The defect's status lives in the tracker; a `knownIssues` line or a dev note references the issue and
**is deleted when it closes**. A workaround the project carries for a framework issue gets the issue, a
dev note and the marker in the code (`dartway-framework-notes`).
