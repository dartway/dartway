import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// The caret rule `caret_check.dart` judges the skeleton by. Pub's rule, not
/// npm's: under a zero major the next breaking version is the next minor.
void main() {
  PlainVersion v(String text) => PlainVersion.tryParse(text)!;

  test('reads a plain X.Y.Z and nothing with a prerelease or build part', () {
    expect(v('1.2.3').toString(), '1.2.3');
    expect(PlainVersion.tryParse('0.20.0-dev.1'), isNull);
    expect(PlainVersion.tryParse('1.2.3+4'), isNull);
    expect(PlainVersion.tryParse('1.2'), isNull);
  });

  test('orders numerically, not as text', () {
    expect(v('0.10.0').compareTo(v('0.9.0')), greaterThan(0));
    expect(v('1.0.0').compareTo(v('0.99.99')), greaterThan(0));
    expect(v('2.1.3').compareTo(v('2.1.3')), 0);
  });

  test('a caret above zero allows up to the next major', () {
    expect(v('1.2.3').allows(v('1.2.3')), isTrue);
    expect(v('1.2.3').allows(v('1.9.0')), isTrue);
    expect(v('1.2.3').allows(v('2.0.0')), isFalse);
    expect(v('1.2.3').allows(v('1.2.2')), isFalse);
  });

  test('a caret under a zero major allows up to the next minor — as pub, '
      'not npm, reads it', () {
    expect(v('0.0.3').allows(v('0.0.4')), isTrue);
    expect(v('0.0.3').allows(v('0.1.0')), isFalse);
    expect(v('0.12.0').allows(v('0.12.9')), isTrue);
    expect(v('0.12.0').allows(v('0.13.0')), isFalse);
  });
}
