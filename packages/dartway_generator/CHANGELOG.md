# Changelog

## 0.21.0-dev.17

- Emit contract descriptor format 2 and introduction `since` metadata for new data objects,
  preserving trusted baseline metadata. New data objects need any shared version raise above the
  trusted base, rather than a breaking-line raise. Format 1 baselines remain valid (#504).

- First contract adoption compares shared's own path-dependency closure at both base and head,
  excluding app-only and dev-only packages. Repointed dependencies remain blocking, the lock walk
  stops at the Git root, and regular files are hashed in one Git call (dartway/dartway#460).
  See the [first descriptor adoption rules](../../docs/2-core/wire-and-versions.md#first-descriptor-adoption)
  for the compared set and output ownership (dartway/dartway#458).

- Recognize the framework `DwCalendarDay` by package identity in DTO codecs and entity rows; record
  its additive `calendarDay` descriptor kind. Direct entity columns map to `DwColumnType.calendarDay`;
  JSONB collections of this value remain unsupported with a diagnostic.

- Emit a deterministic project wire descriptor and verify source-derived contracts against a fixed
  committed Git baseline. Breaking edits require the shared package breaking line to advance;
  unsupported/custom or unreproducible baselines block the check. Descriptor-free commits follow the
  [first descriptor adoption rules](../../docs/2-core/wire-and-versions.md#first-descriptor-adoption).
  A pin-move PR can establish the descriptor; changed source blocks with named paths and instructions to split the change. Remove the now-unreachable reproduction bootstrap.

- The family also moves in lockstep to deliver the migration note for the router
  that follows a provider (dartway/dartway#407).

## 0.21.0-dev.16

- Nothing changed here; the family moves in lockstep to deliver the migration note for the import,
  test layout and spacing checks of `dartway check` (dartway/dartway#391).

## 0.21.0-dev.15

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`
  (dartway/dartway#390).

## 0.21.0-dev.14

- Nothing changed here; the family moves in lockstep to deliver the migration note for the new
  state and command checks of `dartway check` (dartway/dartway#389).

## 0.21.0-dev.13

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#388).

## 0.21.0-dev.12

- **BREAKING: a row class declares `required this.id` and `final int id;`**, and the generator
  writes its draft beside it: `New<Entity>Row` — the same constructor without `id`, defaults
  included — a value with `==`, `hashCode` and `toString` by its columns, a `copyWith` and
  `withId(id)`, and the table's `toDraftRow`. The row's own `copyWith` keeps the id. Reported: a
  row class named like another's draft (`NewPlanRow` beside `PlanRow`), an id with a default
  (`this.id = 0`), and a constructor default the draft cannot repeat (dartway/dartway#384).

## 0.21.0-dev.11

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#387).

## 0.21.0-dev.10

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#386).

## 0.21.0-dev.9

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#385).

## 0.21.0-dev.8

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#355, #356).

## 0.21.0-dev.7

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`, whose `dartway_router` bump changed URLs for `extraPathSegment` (#314).

## 0.21.0-dev.6

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.5

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.2

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (#310, D-087).

## 0.21.0-dev.1

- Nothing changed here; the family moves in lockstep with `dartway_client`, fixed for #309.

## 0.20.0

- First publication of the rewrite to pub.dev.

## 0.20.0-dev.4

- **The shared package's `version:` is the contract version** (#296): written into `dw_protocol.dart` as `contractVersion:`; a shared package without a semantic version is refused. Migration note: `docs/migrations/2026-09-24-contract-version.md`.

## 0.20.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`.

## 0.20.0-dev.2

- **A `Duration` default is read on Dart 3.13**, where the SDK moved the length of a `Duration` constant from `_duration` to `inMicroseconds`: a DTO field defaulting to a `Duration` stopped generation with "the Duration could not be read". Both fields are read, since the family's floor is Dart 3.11.

## 0.20.0-dev.1

The rewrite (see docs/1.0/DECISIONS.md).

- **A `DwOpenEnum` without an `unknown` value is refused** (D-071).

- **A command whose result the wire cannot carry is refused** (#265): `DwActionCommand<List<…>>`, `Map`, `Object`, an enum — anything but `void`, a JSON primitive or a DTO, each possibly nullable — compiled and failed at runtime when the result was encoded; generation now names the command and says to wrap the collection in a DTO.

- **An app package without `pub get` no longer stops generation.** An unresolved `*_flutter` package is skipped and named in the summary (`not scanned: … — run \`dart pub get\` there`, `DwGenerationReport.skipped`); the shared and server packages still generate. `--check` keeps it an error: it cannot call a package it did not read up to date.

- **A row field may be a `List<E>` of an enum** (non-null elements), generated as `DwEnumListType(E.values)`. It used to be refused as a `jsonb` list whose elements are not plain JSON, and projects stored `List<String>` names behind a typed getter (D-064).

- **Row fields `name`, `columns`, `schema`, `table`, `row` (D-040):** generated
  tables override `tableColumns`, schemas and repositories name
  `<Row>.tableDef`, and `fromRow` reaches a column called `row` through `this`.
  A field named like a remaining `DwTableDef` member or `tableDef` is reported.
- **Defaults on the wire (D-041):** a DTO field with a constructor default may
  be absent in JSON and decodes to that default (rebuilt from its constant
  value); a value equal to it is not encoded. A nullable field with a non-null
  default writes an explicit `null`. Required fields without a default stay
  required; patches are unchanged. A default that cannot be rebuilt (a
  framework DTO) is reported.
