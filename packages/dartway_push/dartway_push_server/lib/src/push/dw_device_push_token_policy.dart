import 'dart:convert';

/// Normalization and validation rules for device push tokens.
///
/// A token is an opaque provider address; two visually identical tokens that
/// differ only by surrounding whitespace are the same device. These rules give
/// the module a single canonical form so the `UNIQUE(token)` index can dedupe,
/// cap the number of tokens per recipient, and decide when a token is stale
/// enough to refresh. Pure: no database, no app types.
abstract final class DwDevicePushTokenPolicy {
  static const maximumTokensPerRecipient = 10;
  static const maximumTokenBytes = 1024;
  static const minimumRefreshInterval = Duration(hours: 1);

  /// Unicode whitespace/format code points trimmed from a token to reach its
  /// canonical form. Kept as explicit code points (not a string literal of
  /// invisible characters) so the set is readable and reviewable.
  static const List<int> _canonicalTrimCodePointList = [
    0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x0085, 0x00A0, 0x1680,
    0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008,
    0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF,
  ];

  /// The same trim set as an SQL `U&'...'` literal, for `BTRIM` inside the
  /// store's canonical-token lookup query.
  static const canonicalTrimCharactersSqlLiteral =
      r"U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680"
      r"\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A"
      r"\2028\2029\202F\205F\3000\FEFF'";

  static final Set<int> _canonicalTrimCodePoints =
      _canonicalTrimCodePointList.toSet();

  static String normalize(String token) {
    var start = 0;
    var end = token.length;

    while (start < end) {
      final codePoint = _codePointAt(token, start);
      if (!_canonicalTrimCodePoints.contains(codePoint)) break;
      start += codePoint > 0xFFFF ? 2 : 1;
    }

    while (end > start) {
      final trailingCodePoint = token.substring(0, end).runes.last;
      if (!_canonicalTrimCodePoints.contains(trailingCodePoint)) break;
      end -= trailingCodePoint > 0xFFFF ? 2 : 1;
    }

    return start == 0 && end == token.length
        ? token
        : token.substring(start, end);
  }

  static int _codePointAt(String value, int index) {
    final leading = value.codeUnitAt(index);
    if (leading < 0xD800 || leading > 0xDBFF || index + 1 >= value.length) {
      return leading;
    }

    final trailing = value.codeUnitAt(index + 1);
    if (trailing < 0xDC00 || trailing > 0xDFFF) {
      return leading;
    }

    return 0x10000 + ((leading - 0xD800) << 10) + (trailing - 0xDC00);
  }

  static bool isValid(String normalizedToken) {
    if (normalizedToken.isEmpty || normalizedToken.length > maximumTokenBytes) {
      return false;
    }
    return utf8.encode(normalizedToken).length <= maximumTokenBytes;
  }

  static bool shouldRefresh({
    required DateTime refreshedAt,
    required DateTime now,
  }) => !refreshedAt.toUtc().isAfter(
    now.toUtc().subtract(minimumRefreshInterval),
  );
}
