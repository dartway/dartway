/// A row of an application table as it is stored: the base of every row class
/// (`SessionBookingRow extends DwTableRow`).
///
/// A row never leaves the server (see `docs/4-server/database.md`): handlers map rows to data objects
/// explicitly. The `Row` suffix is required of every row class — its table is
/// `<Name>Table` and its repository `db.<names>` — so a row and the data
/// object shown to clients (`SessionBooking`) never share a name. Its `==`,
/// `hashCode`, `toString` and `copyWith` are generated.
///
/// A row always has its [id]: every row comes out of the database, which
/// assigns it. A row that is not stored yet is a different value, its
/// [DwRowDraft].
abstract class DwTableRow {
  const DwTableRow();

  /// The `bigserial` primary key the database assigned.
  int get id;
}

/// A row before it is inserted: every column of [R] but the id, which the
/// database assigns. What `insert`, `tryInsert`, `insertAll` and `upsert`
/// take; each answers the stored [R].
///
/// Generated for every row class as `New<Name>Row`, with a `copyWith` and a
/// `withId` that turns it into the row stored under an id already known.
abstract class DwRowDraft<R extends DwTableRow> {
  const DwRowDraft();
}
