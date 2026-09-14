/// A row of an application table, as a Dart value: the base of every row
/// class (`SessionBookingRow extends DwTableRow`).
///
/// A row never leaves the server (SPEC §1): handlers map rows to data objects
/// explicitly. The `Row` suffix is required of every row class — its table is
/// `<Name>Table` and its repository `db.<names>` — so a row and the data
/// object shown to clients (`SessionBooking`) never share a name. Its `==`,
/// `hashCode`, `toString` and `copyWith` are generated.
abstract class DwTableRow {
  const DwTableRow();

  /// The `bigserial` primary key; `null` until the row is inserted.
  int? get id;
}
