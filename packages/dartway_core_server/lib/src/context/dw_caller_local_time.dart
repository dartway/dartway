/// What the caller's clock reads at an instant: `ctx.callerLocalTime`.
///
/// A wall-clock reading, not an instant, and deliberately not a `DateTime`:
/// a `DateTime` holding local fields would pass for an instant everywhere one
/// is accepted — a DTO field, a `timestamptz` column, `isBefore`,
/// `toIso8601String` with its `Z` — and be wrong by the offset each time.
/// The one way back to an instant is named: [startOfDayUtc].
final class DwCallerLocalTime {
  /// The reading of a clock [offset] east of UTC at [instant].
  DwCallerLocalTime(DateTime instant, this.offset)
    : _fields = instant.toUtc().add(offset);

  /// The caller's UTC offset the reading was taken with.
  final Duration offset;

  // UTC fields shifted by the offset: they read as the caller's clock. Never
  // handed out.
  final DateTime _fields;

  int get year => _fields.year;
  int get month => _fields.month;
  int get day => _fields.day;
  int get hour => _fields.hour;
  int get minute => _fields.minute;

  /// `DateTime.monday` (1) to `DateTime.sunday` (7), on the caller's date.
  int get weekday => _fields.weekday;

  /// The instant the caller's current day began: their local midnight, in
  /// UTC — the lower bound of a query over "the caller's today".
  DateTime get startOfDayUtc =>
      DateTime.utc(year, month, day).subtract(offset);

  @override
  bool operator ==(Object other) =>
      other is DwCallerLocalTime &&
      other._fields == _fields &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(_fields, offset);

  /// `2026-09-30 00:30 (UTC+03:00)`: the reading and its offset, never
  /// something that parses as an instant.
  @override
  String toString() {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '${year.toString().padLeft(4, '0')}-${two(month)}-${two(day)} '
        '${two(hour)}:${two(minute)} '
        '(UTC$sign${two(minutes ~/ 60)}:${two(minutes % 60)})';
  }
}
