import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  group('DwWindowCursor', () {
    test('round-trips int, String and DateTime sort values', () {
      final at = DateTime.utc(2026, 9, 14, 10, 30, 0, 123, 456);
      for (final (sortValue, id) in <(Object, Object)>[
        (42, 7),
        (-3, 'b-7'),
        ('Zoë & co / 100%', 7),
        ('', ''),
        (at, 7),
        (DateTime.utc(1969, 12, 31, 23, 59, 59), 'x'),
      ]) {
        final cursor = DwWindowCursor.encode(sortValue, id);
        final back = DwWindowCursor.decode(cursor);
        expect(back.sortValue, sortValue, reason: cursor);
        expect(back.id, id, reason: cursor);
        expect(back, DwWindowCursor(sortValue, id));
      }
    });

    test('is URL-safe: nothing to escape, no padding', () {
      final cursor = DwWindowCursor.encode('???>>>~~~ ', 'ÿÿÿ');
      expect(cursor, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(Uri.encodeQueryComponent(cursor), cursor);
    });

    test('ties on the sort value are told apart by the id', () {
      final at = DateTime.utc(2026, 9, 14);
      final first = DwWindowCursor.encode(at, 7);
      final second = DwWindowCursor.encode(at, 8);
      expect(first, isNot(second));
      expect(DwWindowCursor.decode(first).id, 7);
      expect(DwWindowCursor.decode(second).id, 8);
      expect(
        DwWindowCursor.decode(first).sortValue,
        DwWindowCursor.decode(second).sortValue,
      );
    });

    test('a local DateTime travels as its instant and decodes as UTC', () {
      final local = DateTime(2026, 9, 14, 12);
      final back = DwWindowCursor.decode(DwWindowCursor.encode(local, 1));
      final sortValue = back.sortValue as DateTime;
      expect(sortValue.isUtc, isTrue);
      expect(sortValue.isAtSameMomentAs(local), isTrue);
    });

    test('an int and a String of the same digits are different positions', () {
      expect(DwWindowCursor.encode(1, 1), isNot(DwWindowCursor.encode('1', 1)));
      expect(DwWindowCursor.encode(1, 1), isNot(DwWindowCursor.encode(1, '1')));
    });

    test('unsupported values are refused when building', () {
      expect(() => DwWindowCursor.encode(1.5, 1), throwsArgumentError);
      expect(() => DwWindowCursor.encode(true, 1), throwsArgumentError);
      expect(
        () => DwWindowCursor.encode(1, DateTime.utc(2026)),
        throwsArgumentError,
      );
    });

    test('a forged or damaged cursor is a FormatException', () {
      final valid = DwWindowCursor.encode(42, 7);
      String forge(Object? json) =>
          base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
      for (final cursor in [
        '',
        '!!!',
        '$valid=',
        valid.substring(1),
        forge({}),
        forge([1, 2]),
        forge(['i', '42', 7]), // the tag and the value disagree
        forge(['x', 42, 7]), // an unknown tag
        forge(['i', 42, null]),
        forge(['i', 42, 1.5]),
        base64Url.encode([0xff, 0xfe]).replaceAll('=', ''), // not UTF-8
      ]) {
        expect(
          () => DwWindowCursor.decode(cursor),
          throwsFormatException,
          reason: cursor,
        );
      }
    });

    test('positions compare by sort value, then id', () {
      final at = DateTime.utc(2026, 9, 14);
      int compare(Object s1, Object i1, Object s2, Object i2) =>
          DwWindowCursor.comparePositions(
            (sortValue: s1, id: i1),
            (sortValue: s2, id: i2),
          );
      expect(compare(2, 1, 1, 9), greaterThan(0));
      expect(compare(1, 2, 1, 1), greaterThan(0));
      expect(compare('a', 'x', 'b', 'a'), lessThan(0));
      expect(compare(at, 3, at, 3), 0);
      expect(
        compare(at.toLocal(), 1, at, 2),
        lessThan(0),
        reason: 'instants, whatever the zone',
      );
      expect(DwWindowCursor.decode(DwWindowCursor.encode(at, 5)).position, (
        sortValue: at,
        id: 5,
      ));
      expect(() => compare(1, 1, 'a', 1), throwsArgumentError);
    });
  });
}
