/// A Gregorian calendar date with no time or time zone.
///
/// The supported range is `0001-01-01` through `9999-12-31`. Construct a day
/// from components selected in the calendar zone your application intends;
/// this type never chooses a zone or turns a date into an instant.
final class DwCalendarDay implements Comparable<DwCalendarDay> {
  DwCalendarDay(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'must be between 1 and 9999');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be between 1 and 12');
    }
    final lastDay = _daysInMonth(year, month);
    if (day < 1 || day > lastDay) {
      throw ArgumentError.value(day, 'day', 'must be between 1 and $lastDay');
    }
  }

  /// The four digit Gregorian year, from 1 through 9999.
  final int year;

  /// The month, from 1 through 12.
  final int month;

  /// The day of the month, from 1 through that month's length.
  final int day;

  /// Parses exactly `YYYY-MM-DD`, rejecting noncanonical and invalid dates.
  factory DwCalendarDay.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException(
        'Expected a calendar day in YYYY-MM-DD form',
        value,
      );
    }
    try {
      return DwCalendarDay(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    } on ArgumentError {
      throw FormatException('Invalid Gregorian calendar day', value);
    }
  }

  /// Returns this date shifted by [days], throwing outside years 0001–9999.
  DwCalendarDay addDays(int days) {
    final ordinal = _ordinal;
    final last = _daysBeforeYear(10000) - 1;
    if (days < -ordinal || days > last - ordinal) {
      throw RangeError('Calendar day arithmetic exceeds years 0001–9999');
    }
    return _fromOrdinal(ordinal + days);
  }

  /// The signed number of days from [other] to this date.
  int differenceInDays(DwCalendarDay other) => _ordinal - other._ordinal;

  int get _ordinal =>
      _daysBeforeYear(year) + _daysBeforeMonth(year, month) + day - 1;

  static DwCalendarDay _fromOrdinal(int ordinal) {
    final max = _daysBeforeYear(10000);
    if (ordinal < 0 || ordinal >= max) {
      throw RangeError('Calendar day arithmetic exceeds years 0001–9999');
    }
    var low = 1;
    var high = 10000;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (_daysBeforeYear(middle) <= ordinal) {
        low = middle;
      } else {
        high = middle;
      }
    }
    var dayOfYear = ordinal - _daysBeforeYear(low);
    var month = 1;
    while (dayOfYear >= _daysInMonth(low, month)) {
      dayOfYear -= _daysInMonth(low, month++);
    }
    return DwCalendarDay(low, month, dayOfYear + 1);
  }

  static int _daysBeforeYear(int year) {
    final completed = year - 1;
    return completed * 365 +
        completed ~/ 4 -
        completed ~/ 100 +
        completed ~/ 400;
  }

  static int _daysBeforeMonth(int year, int month) {
    var days = 0;
    for (var current = 1; current < month; current++) {
      days += _daysInMonth(year, current);
    }
    return days;
  }

  static int _daysInMonth(int year, int month) => switch (month) {
    2 => _isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  static bool _isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  @override
  int compareTo(DwCalendarDay other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    return byMonth != 0 ? byMonth : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is DwCalendarDay &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
