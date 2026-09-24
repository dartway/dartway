---
name: dartway-documentation
description: >-
  Where a DartWay project's descriptions live, and what a document in `docs/` must earn: a feature's
  behaviour in its `DwFeatureSpec`, a DTO's meaning above the DTO, a handler's access and effects
  above the handler, a registry as an enum; `docs/adr/` for decisions and the alternatives they ruled
  out; `docs/dev_notes/` for findings with no address in code, one file each, referencing the
  tracker. Use before writing or changing any documentation, a `DwFeatureSpec`, `knownIssues`, an
  ADR or a dev note, and when deciding where a finding goes.
---

# DartWay — documentation lives in the code (`dartway-documentation`)

**There are no separate "a file per feature" docs in the project.** To learn about a feature, ask its code:

| What you need to know | Where to look |
|---|---|
| what the feature does, what to expect from it, where the traps are | `DwFeatureSpec` in its public file |
| what is wrong with the feature and worth picking up | `knownIssues` in that same spec |
| what a request or command means, its fields and their invariants | the doc comments on the DTO in `__SHARED_PKG__` |
| who may call it, what it changes, what it publishes and where | the doc comment above its handler in `__SERVER_PKG__` |
| who may listen to a channel, and what travels on it | the doc comments on the channel kind and on its rule |

**Why so.** A doc sitting apart from the code drifts from it silently: the compiler does not check it, the checker does not see it, and the agent reads it and believes it. On a production project such a doc described an API deleted a year earlier, and non-working code was written from it. A spec in the feature's file and a comment above the handler survive a code edit because they lie in the same diff.

**A new project gets no `docs/` folder for architecture, and most of what you would put in one belongs elsewhere.**

| What it is | Where it lives |
|---|---|
| A cross-cutting registry — analytics events, settings keys, roles | Code: an enum in `__SHARED_PKG__` when both sides use it, in `lib/core/` of the app otherwise, with doc comments. The compiler knows the list, and a typo is an error rather than a discrepancy |
| The roles and access matrix | The doc comments above the handlers and rules — the rule sits where it is enforced |
| An external integration's payload | Doc comments on the route (`DwHttpRoute`) that receives it |
| "How this app is put together" | The skills. The methodology ships from the framework and is updated with it; a copy inside the project would only fall behind |
| A checkup report | The chat. `/dartway-checkup` writes no report file on purpose: what belongs to a feature becomes a line in its `knownIssues`, what belongs to the project goes to `docs/dev_notes/`, and the rest was worth saying once |

Before starting any document, name what it would say that a `DwFeatureSpec`, a doc comment or a piece of code cannot. Usually the answer is that the spec is silent where it should not be, and the fix is in the spec.

**`docs/` is for what survives that question.** Two kinds are known to the framework and have rules, because they are the ones that keep being reinvented.

### `docs/adr/` — the decisions, and what they ruled out

An ADR records **the alternatives that were rejected, and why**. That is the one thing which cannot live beside the code: a rejected option has no file to sit next to. What the decision *produced* is in the code already.

**The admission test is one question:** is there an alternative someone will propose again in six months? If not, this is not an ADR, and what you wanted to write belongs in a spec or a doc comment.

`docs/adr/NNNN-slug.md` — four digits, flat, written in this project's language. Each one carries:

- **Status** — `accepted` or `superseded by NNNN` — and the date;
- **Context** — what forced a choice;
- **Decision** — what was chosen;
- **Rejected alternatives, each with its reason** — without this section the document is not an ADR;
- **Limitations accepted knowingly** — what you are choosing to live with.

**Never write "how it works now".** That is the part that rots, and it rots silently, because the code changes under it without an error.

**An ADR is never edited — it is superseded by a new one**, and the old one gets `superseded by NNNN` in its status. Editing destroys the only thing it is for: what was known at the moment of the choice.

**This is a default, and a project may replace it** — see "Law and default" in `CLAUDE.md`. What must not be destroyed is *what was known at the moment of the choice*; a new number preserves that, and so does a change log at the end of one long-lived file. If the project has decided otherwise, its decision belongs in its root `CLAUDE.md` with the reason — **check there before opening a number**.

**Planning reads them.** `dartway-plan` looks in `docs/adr/` before proposing an approach, so a decision whose alternatives were already weighed is not re-argued from scratch — and a plan that itself makes such a choice proposes a new ADR as one of its steps.

### `docs/dev_notes/` — the findings with no address in code

A finding this project made that **does not fit the task at hand and is not confined to a single feature**: CI that runs less than it declares, a pin that trails, a config written down twice, a tendency you keep seeing.

**The admission test is whether the finding has an address in code.** Take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed right now | fix it — no entry anywhere |
| belongs to one feature or screen | that feature's `knownIssues` in its `DwFeatureSpec` |
| **has no address in code** — cross-cutting, infrastructural, a decision with a price | `docs/dev_notes/` |

If the finding has an address, it lives at that address, where the compiler, `dart run dartway_cli:dartway check`, Studio and the next reader all pass by it — one product-level sentence in `knownIssues`, deleted when the fix lands. What that field is for is written on the field itself, in `DwFeatureSpec`'s doc comment; it is not restated here.

**The defect itself lives in the tracker; a `knownIssues` line and a `docs/dev_notes/` entry only reference it.** The issue holds the status, the discussion and the pull request that closes it, and an entry repeating any of that is a second copy of a state that changes elsewhere. When the issue closes, delete the file.

`docs/dev_notes/<slug>.md`, one file per finding, no numbering, written in this project's language. Each one is short — where, what is wrong, what we did about it, and the issue:

```markdown
# <short title>

- **Issue:** owner/repo#123
- **Where:** `path/file.dart:12` — or the area, if it is not one place
- **What is wrong:** one or two sentences
- **What we did about it:** the workaround that is in place, or nothing yet
- **Possible direction:** optional, one line
```

**Committed, not git-ignored, and that is the whole design:** an ignored journal travels out through no pull request, appears in no review, and `git worktree remove` deletes it without a word. **One file per finding rather than one file appended to**, because parallel branches appending to one journal conflict on the same lines; separate files have nothing to conflict on.

`docs/dev_notes/_coverage.md` sits beside the entries and is not one: it is the table `/dartway-checkup` keeps of which features have had a deep pass, and when.
