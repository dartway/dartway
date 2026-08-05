import 'package:dartway_cli/src/version_check.dart';
import 'package:test/test.dart';

void main() {
  group('isAtLeastVersion', () {
    test('accepts an equal version', () {
      expect(isAtLeastVersion('3.11.0', '3.11.0'), isTrue);
    });

    test('compares minor versions numerically, not as text', () {
      // The whole reason this function exists: as strings, '3.9' > '3.11'.
      expect(isAtLeastVersion('3.11.0', '3.9.0'), isTrue);
      expect(isAtLeastVersion('3.9.0', '3.11.0'), isFalse);
    });

    test('compares patch versions', () {
      expect(isAtLeastVersion('3.11.2', '3.11.10'), isFalse);
      expect(isAtLeastVersion('3.11.10', '3.11.2'), isTrue);
    });

    test('a newer major wins over a larger minor', () {
      expect(isAtLeastVersion('4.0.0', '3.41.0'), isTrue);
      expect(isAtLeastVersion('2.99.99', '3.0.0'), isFalse);
    });

    test('a missing component counts as zero', () {
      expect(isAtLeastVersion('3.11', '3.11.0'), isTrue);
      expect(isAtLeastVersion('3.11', '3.11.1'), isFalse);
    });

    test('ignores pre-release and build suffixes', () {
      // `dart --version` reports these on non-stable channels; a prerequisite
      // check cares about the release the build belongs to.
      expect(isAtLeastVersion('3.12.0-beta.1', '3.11.0'), isTrue);
      expect(isAtLeastVersion('3.11.0+hotfix', '3.11.0'), isTrue);
    });
  });
}
