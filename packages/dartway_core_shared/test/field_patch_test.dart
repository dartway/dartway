import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

/// A patch built where `T` cannot be inferred for a constant — a conditional
/// in a generic function, the way a command is assembled from a form.
DwFieldPatch<T> _fromForm<T>(T? value) =>
    value == null ? const DwFieldPatch.clear() : DwFieldPatch.set(value);

DwFieldPatch<T> _keptOr<T>(T? value, {required bool touched}) =>
    touched ? DwFieldPatch.set(value as T) : const DwFieldPatch.keep();

void main() {
  test('a constant clear or keep applies to a value of any type', () {
    // `const DwFieldPatch.clear()` there is a DwClearField<Never>; applying it
    // used to fail with "String is not a subtype of Null".
    final cleared = _fromForm<String>(null);
    expect(cleared.apply('before'), isNull);
    final kept = _keptOr<int>(null, touched: false);
    expect(kept.apply(7), 7);
    expect(kept.isKept, isTrue);
    expect(_fromForm<String>('after').apply('before'), 'after');
  });

  group('reading a patch without matching its variants', () {
    test('isSet, isCleared and isKept say which it is', () {
      const DwFieldPatch<int> set = DwFieldPatch.set(3);
      const DwFieldPatch<int> cleared = DwFieldPatch.clear();
      const DwFieldPatch<int> kept = DwFieldPatch.keep();
      expect([set.isSet, set.isCleared, set.isKept], [true, false, false]);
      expect(
        [cleared.isSet, cleared.isCleared, cleared.isKept],
        [false, true, false],
      );
      expect([kept.isSet, kept.isCleared, kept.isKept], [false, false, true]);
    });

    test('newValue is the value a set patch writes, and null otherwise', () {
      expect(const DwFieldPatch<int>.set(3).newValue, 3);
      expect(_fromForm<int>(null).newValue, isNull);
      expect(_keptOr<int>(null, touched: false).newValue, isNull);
    });

    test('map converts the value a set patch writes, and nothing else', () {
      String url(int id) => 'https://files/$id';
      expect(
        const DwFieldPatch<int>.set(7).map(url),
        const DwFieldPatch<String>.set('https://files/7'),
      );
      expect(_fromForm<int>(null).map(url).isCleared, isTrue);
      expect(_keptOr<int>(null, touched: false).map(url).isKept, isTrue);
    });

    test('apply of a default is the value a new row takes', () {
      // Kept on insert means the column's default, cleared means null.
      expect(_keptOr<int>(null, touched: false).apply(10), 10);
      expect(_fromForm<int>(null).apply(10), isNull);
      expect(_fromForm<int>(4).apply(10), 4);
    });
  });

  group('trimmedOrCleared', () {
    test('trims a set text', () {
      expect(
        const DwFieldPatch<String>.set('  Anna ').trimmedOrCleared,
        const DwFieldPatch<String>.set('Anna'),
      );
    });

    test('turns a blank text into a clear', () {
      for (final blank in ['', '   ', '\n\t']) {
        expect(
          DwFieldPatch<String>.set(blank).trimmedOrCleared.isCleared,
          isTrue,
          reason: '"$blank"',
        );
      }
    });

    test('leaves a kept or cleared patch as it is', () {
      expect(
        _keptOr<String>(null, touched: false).trimmedOrCleared.isKept,
        isTrue,
      );
      expect(_fromForm<String>(null).trimmedOrCleared.isCleared, isTrue);
    });

    test('applies like any patch', () {
      expect(
        const DwFieldPatch<String>.set('  ').trimmedOrCleared.apply('before'),
        isNull,
      );
      expect(
        const DwFieldPatch<String>.set(' after ').trimmedOrCleared.apply(null),
        'after',
      );
    });
  });
}
