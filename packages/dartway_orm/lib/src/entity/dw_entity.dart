/// A row of an application table, as a Dart value.
///
/// An entity never leaves the server (SPEC §1): handlers map entities to
/// data objects explicitly. Its `==`, `hashCode`, `toString` and `copyWith`
/// are generated.
abstract class DwEntity {
  const DwEntity();

  /// The `bigserial` primary key; `null` until the row is inserted.
  int? get id;
}
