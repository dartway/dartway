import 'dart:convert';

/// A position in the sequence of a `DwWindowRequest`: the sort value and the
/// id of a row.
///
/// The pair, not the sort value alone, is the position: rows sharing a
/// timestamp are ordered by id, so reading "before (t, 7)" neither skips the
/// other rows at `t` nor repeats row 7. On the wire it is an opaque URL-safe
/// string the server builds and the client passes back untouched — the client
/// never learns which column the sequence is sorted by.
final class DwWindowCursor {
  /// Throws [ArgumentError] for a sort value that is not an `int`, a
  /// `String` or a `DateTime`, or an id that is not an `int` or a `String`.
  DwWindowCursor(this.sortValue, this.id) {
    if (sortValue is! int && sortValue is! String && sortValue is! DateTime) {
      throw ArgumentError.value(
        sortValue,
        'sortValue',
        'a window cursor sorts by an int, a String or a DateTime',
      );
    }
    if (id is! int && id is! String) {
      throw ArgumentError.value(id, 'id', 'an id is an int or a String');
    }
  }

  /// The cursor string of the row with [sortValue] and [id].
  static String encode(Object sortValue, Object id) =>
      DwWindowCursor(sortValue, id).encoded;

  /// Reads a cursor string produced by [encode]. Throws [FormatException] for
  /// anything else — a cursor comes from the client, and a forged or damaged
  /// one is a malformed call.
  static DwWindowCursor decode(String cursor) {
    FormatException malformed() =>
        FormatException('Not a window cursor', cursor);
    if (cursor.isEmpty || !_alphabet.hasMatch(cursor)) throw malformed();
    final Object? json;
    try {
      json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
      );
    } on FormatException {
      throw malformed();
    }
    if (json is! List<Object?> || json.length != 3) throw malformed();
    final [tag, value, id] = json;
    if (id is! int && id is! String) throw malformed();
    final Object sortValue = switch ((tag, value)) {
      (_tagInt, final int v) => v,
      (_tagString, final String v) => v,
      (_tagDateTime, final int v) => DateTime.fromMicrosecondsSinceEpoch(
        v,
        isUtc: true,
      ),
      _ => throw malformed(),
    };
    return DwWindowCursor(sortValue, id!);
  }

  /// An `int`, a `String` or a UTC `DateTime` (a decoded cursor's time is
  /// always UTC: the cursor carries the instant).
  final Object sortValue;

  /// An `int` or a `String`.
  final Object id;

  static const _tagInt = 'i';
  static const _tagString = 's';
  static const _tagDateTime = 't';

  /// base64url without padding.
  static final _alphabet = RegExp(r'^[A-Za-z0-9_-]+$');

  /// The cursor string: base64url (unpadded) of `[tag, value, id]` — JSON,
  /// so a string sort value or id needs no escaping rules of its own.
  String get encoded {
    final value = sortValue;
    final json = switch (value) {
      int() => [_tagInt, value, id],
      String() => [_tagString, value, id],
      DateTime() => [_tagDateTime, value.toUtc().microsecondsSinceEpoch, id],
      _ => throw StateError('unreachable: checked by the constructor'),
    };
    return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  }

  @override
  bool operator ==(Object other) =>
      other is DwWindowCursor && other.sortValue == sortValue && other.id == id;

  @override
  int get hashCode => Object.hash(sortValue, id);

  @override
  String toString() => 'DwWindowCursor($sortValue, $id)';
}
