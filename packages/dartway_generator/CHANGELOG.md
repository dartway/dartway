# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

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
