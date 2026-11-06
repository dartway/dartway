## 7. Generation

After any DTO (or row class) change: `dartway generate`, and commit the output with the change.
Resolve a trusted baseline once with
`git merge-base HEAD origin/__BASE_BRANCH__` and pass that SHA as `--contract-base <SHA>` to generation
and checks — unless `.agents/dartway-toolkit.json` names a `releaseBranch`: then pass no
`--contract-base` and never edit `version:`; the release raises it (`generate --release`, D-158).
It writes `*.dw.dart`, `lib/generated/dw_protocol.dart` and the sorted
`lib/generated/dw_contract.json` here, row
parts and `lib/generated/dw_schema.dart` in the server. Never edit them; a refused declaration is fixed
in the declaration.

## 8. A DTO change reaches installed app builds

An installed build keeps calling with the contract it was built with, for weeks.

| Change | An old build |
|---|---|
| a nullable, defaulted or patch field; a new call | generated codecs accept omitted fields and ignore extra keys |
| a required non-null field without a default | the new codec cannot decode the old payload; add it nullable or defaulted |
| a wire name/field removed or renamed; a type, nullability, patch or default changed | may reject or discard installed-client data; breaking |
| a value added to a strict enum | an old decoder rejects it; breaking |
| a value added to an already-open enum with all old values retained | old decoders read the new name as `unknown` |
| a new generated data object type | additive with a shared version above the trusted base (a patch is enough); generated `since` keeps its updates and deletions from older builds |
| a request/command renamed or removed | `404` |
| a refusal code renamed | its generic refusal text |

With a `releaseBranch`, the next two paragraphs are the release's: a task keeps `version:` and its PR
says which kind of change it is.

Prefer the additive change. Retire a field, enum value or call over two store releases: first mark it
with `@DwContractDeprecation`, then remove it only after the marked build reaches both stores and its
baseline is updated. **Raising the breaking line of `__SHARED_PKG__/pubspec.yaml`'s `version:` is the
exception** for an unavoidable incompatible change — the minor below 1.0, the major after — and sends
apps of the older line to the update screen with `426`. A new data object must raise the shared version
above the trusted base; a patch is enough. Other additive changes may keep the version. Nothing is set
in an environment at deploy time: the minimum ships with the code. The commit and the PR say which
kind of change it is, and an exceptional breaking-line raise names the version it raises to.

**Open enums** — every enum reachable from a data-object field or request/command result uses
`with DwOpenEnum` and a value `unknown`, including statuses and roles. Handle `unknown` explicitly in
exhaustive switches. An enum reachable only from fields the client sends may stay strict. To migrate,
add only `unknown`, ship that build, wait for both stores, and update the baseline before adding a
real value.

Contract tests (round trip, `validate()`, `onUpdate`, channels): `dartway-testing`.

After a build is live in both stores, `dartway contract baseline` commits the generated descriptor
as `contract_baseline.json` next to the shared package pubspec. Additions that the baseline codecs tolerate do not raise
the breaking line. Retire a field, enum value or call by marking it
`@DwContractDeprecation(since: '<contract version>')`; removal is allowed only after that mark is in the store
baseline. A marked field is nullable or has a default so the marked build survives its absence; its
`since` is not newer than the contract version. Release CI runs `dartway check --release`, which requires marks already in the baseline to
be removed. Never update the baseline while either store is still reviewing the build.

`projectContractVersion` is an error when the generated project contract is incompatible at the
same line or cannot be verified. The generator compares its resolved source models in memory with
the descriptor read from the fixed Git commit; regeneration or editing the working JSON cannot
erase that baseline. Without a committed descriptor, follow the
[first descriptor adoption rules in the framework repository](https://github.com/dartway/dartway/blob/master/docs/2-core/wire-and-versions.md#first-descriptor-adoption).
The pin-move PR regenerates output and establishes the first descriptor;
changed compared source blocks and names the files. Split it: land the pin move with
unchanged shared source and in-repo path dependencies first, then the contract edit in a following PR. A committed
base descriptor always wins. No historical dependency fetch or codec reproduction
is used. Malformed or unsupported contracts remain blocking. CI supplies its trusted
base SHA explicitly; ordinary check uses the project's recorded base branch merge-base,
or an unambiguous remote HEAD/main/master. It never chooses feature HEAD as a fallback.

This proves generated codecs and registry shapes, including nested fields and resolved request/result
kinds. It does not prove handler/domain semantics or manually composed external module contracts.
Custom codecs, visible custom enum `name` encoders and custom DTO equality used by default omission are unverified. This tooling metadata changes neither runtime negotiation nor the
framework `dwProtocolVersion`.

A new path dependency between project packages is named in both Dockerfiles, or `pub get` in the
image fails. The shared package is the client contract; there is no separate client package.
