import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  test('an identifier is sorted by its at sign, and only by it (#283)', () {
    expect(DwIdentifierKind.of('ann@example.com'), DwIdentifierKind.email);
    expect(DwIdentifierKind.of('a@b'), DwIdentifierKind.email);
    expect(DwIdentifierKind.of('+7 999 000-00-01'), DwIdentifierKind.phone);
    // It sorts, it does not validate: normalising is the project's.
    expect(DwIdentifierKind.of('not a phone'), DwIdentifierKind.phone);
  });
}
