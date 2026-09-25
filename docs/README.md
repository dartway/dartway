# DartWay documentation

This folder is the **only** source of dartway.dev content. It lives in the framework monorepo so a
page and the code it describes travel in the same PR — the synchronisation law in the root
`CLAUDE.md`.

## Sections

| Folder | What belongs there |
|---|---|
| `1-getting-started/` | What DartWay is, how to bring a project up by hand or with an agent, what `dartway create` gives you |
| `2-core/` | The contract both sides speak: data objects and generation, requests and updates, commands and idempotency, refusals and statuses, channels, access, the wire and its versions |
| `3-flutter/` | The app side: the Flutter core, the data layer, the window list, actions and refusal texts, the update-required screen, uploads, error reporting, features, the UI kit, plugins, push |
| `4-server/` | The server: the app server, handlers and their context, the database, migrations, accounts and identities, uploads, jobs, routes, alerts, push delivery, analytics |
| `5-tooling/` | The CLI, testing, deploy, the conventions checker, the agent toolkit |
| `6-studio/` | DartWay Studio and the bridge an app opens to it |
| `migrations/` | Notes on what a project has to change when it moves to a newer framework — read by `dartway update` |

`DESIGN.md` is not documentation. It is the law of how the framework's own public API is designed —
written for whoever changes the framework, not for whoever uses it, and it is not published.

## How a page is written

**Every claim is checked against the code before it is written.** Not against another page, not
against memory. A page that has drifted is worse than a missing one: the compiler does not check it,
the checker cannot see it, and the reader — increasingly an agent — believes it. That has already
happened here, and code was written against an API that had been deleted.

- **One page, one question.** The title is the question a reader arrives with.
- **Say why, not only how.** The "how" is in the code; a page earns its place by explaining the
  decision behind it — why a command carries an idempotency key, why a refusal is a code and not a
  sentence, why the framework ships no design.
- **Every code sample compiles against `example/`.** Prefer lifting the sample straight out of it,
  with its path, so that a change to the API breaks the example first and the page is fixed in the
  same PR. What a test can hold, a test holds: `packages/dartway_cli/test/docs_identifiers_test.dart`
  fails when a `Dw…` name on a page is declared in no public library of the framework, and when a
  relative link between pages does not resolve.
- **Name the failure, not just the rule.** What breaks if you do it the other way is the part
  readers remember.
- **English, and no filler.** Short statements. No "it is important to note that".
- **Do not repeat a skill.** `toolkit/skills/` instructs an agent working inside a project; these
  pages explain the framework to a person. Where both would say the same thing, the page says what
  it is and the skill says what to do about it.

## What is not here

- Per-feature documentation of an application — an app describes its features in its own code, in
  `DwFeatureSpec` (see `3-flutter/features-and-specs.md`).
- Planning and roadmaps. `1.0/` is the rewrite's working record — the spec, the contracts and the
  decisions taken during the build — not documentation: where it disagrees with the code, the code
  wins, and a page is written from the code.
- API reference — that is what doc comments are for, and pub.dev renders them.
