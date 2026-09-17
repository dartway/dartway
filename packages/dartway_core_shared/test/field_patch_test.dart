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
}
