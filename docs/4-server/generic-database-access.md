# Working with a model you only know as a type

Most server code names its model. `ClubSession.db.findById(session, id)` is typed, public, generated
for you, and it is the right call — this page is not about replacing it.

It is about the other kind of code: a data migration, a background cleanup, an export, a purge. There
the model is a **type parameter**, the body is the same for every one of them, and Serverpod has
nothing to offer. It generates a repository per model and none of a common type, so there is no
`Repository<T>` to be handed. Its generic equivalents do exist — `session.db.find<T>()`,
`insertRow<T>`, `updateRow<T>` — and every one of them is annotated `@internal`.

That leaves an application two bad options: silence the analyzer with
`// ignore_for_file: invalid_use_of_internal_member`, which is reaching into another package's
private surface, or write a three-line adapter per model whose bodies differ only in the model's
name.

## `dw.db(session)`

```dart
Future<int> purgeStale<T extends TableRow>(Session session, Expression stale) async {
  final db = dw.db(session);
  final rows = await db.find<T>(where: stale);
  for (final row in rows) {
    await db.deleteRow<T>(row);
  }
  return rows.length;
}
```

Five operations, and deliberately only five:

| | |
|---|---|
| `find<T>({where, limit, offset, orderBy, orderByList, orderDescending, include, transaction})` | the rows |
| `count<T>({where, limit, transaction})` | how many, without reading them |
| `insertRow<T>(row, {transaction})` | returns the row with its id |
| `updateRow<T>(row, {transaction})` | the row must carry its id |
| `deleteRow<T>(row, {transaction})` | returns what was deleted |

**Every one takes an optional `transaction`, and inside a save hook it is not optional in practice.**
A call that omits it runs on its own connection: it cannot see the uncommitted rows around it and is
not rolled back with them — and under `serverpod_test` with database rollbacks enabled, which is the
default, it fails outright as a concurrent database call. Pass `saveContext.transaction`. The same
applies to the framework's own profile reads, which take the argument for the same reason:
`dw.currentUserProfile(session, transaction: saveContext.transaction)`.

## Why this is not a second `session.db`

Because the `ignore` has to live somewhere, and there is one good place for it.

Concentrated in the core, it is written once and no application repeats it. When Serverpod changes
those methods — they are marked internal precisely because it reserves the right to — one file needs
fixing rather than every application that ever wrote a migration. And a facade over generic database
access is the seam a replacement for the ORM would be fitted into, which a scatter of
`ignore_for_file` lines across N projects would not be.

The set stays small on purpose (see `DESIGN.md`: the core is a minimal contract). If something real
needs `deleteWhere` or a lock mode, it gets added then — not in advance.
