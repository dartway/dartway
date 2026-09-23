# Changelog

## 0.20.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`.

## 0.20.0-dev.2

- **A `Duration` default is read on Dart 3.13**, where the SDK moved the length of a `Duration` constant from `_duration` to `inMicroseconds`: a DTO field defaulting to a `Duration` stopped generation with "the Duration could not be read". Both fields are read, since the family's floor is Dart 3.11.

## 0.20.0-dev.1

The rewrite (see docs/1.0).

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
