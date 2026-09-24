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

    test('a pre-release suffix never leaks in as an extra release component '
        '— `0.20.0-dev.4`\'s trailing "4" used to be read as a fourth release '
        'component, making the plain `0.20.0` that shipped it compare as '
        '*older* than the dev build it replaced (#307). This function still '
        'answers "same release", which is what an SDK check wants; a '
        "package's own version wants isPackageAtLeastVersion below", () {
      expect(isAtLeastVersion('0.20.0', '0.20.0-dev.4'), isTrue);
      expect(isAtLeastVersion('0.20.0', '0.20.0-dev.1'), isTrue);
      expect(isAtLeastVersion('0.19.0', '0.20.0-dev.1'), isFalse);
    });
  });

  group('isPackageAtLeastVersion', () {
    test('accepts an equal version', () {
      expect(isPackageAtLeastVersion('0.20.0', '0.20.0'), isTrue);
    });

    test('compares minor and patch versions numerically, not as text', () {
      expect(isPackageAtLeastVersion('0.11.0', '0.9.0'), isTrue);
      expect(isPackageAtLeastVersion('0.9.0', '0.11.0'), isFalse);
      expect(isPackageAtLeastVersion('0.11.10', '0.11.2'), isTrue);
      expect(isPackageAtLeastVersion('0.11.2', '0.11.10'), isFalse);
    });

    test('a pre-release sorts below the release it precedes — a project on '
        '0.20.0-dev.1 is behind the 0.20.0 that shipped after it, and '
        "0.20.0-dev.4 does not satisfy a note keyed to plain 0.20.0 (review "
        'of #308, the case isAtLeastVersion could not tell apart from "same '
        'release")', () {
      expect(isPackageAtLeastVersion('0.20.0-dev.4', '0.20.0'), isFalse);
      expect(isPackageAtLeastVersion('0.20.0', '0.20.0-dev.4'), isTrue);
      expect(isPackageAtLeastVersion('0.20.0-dev.1', '0.20.0'), isFalse);
    });

    test('pre-release identifiers compare numerically, so dev.9 sorts below '
        'dev.10 rather than as text', () {
      expect(isPackageAtLeastVersion('0.20.0-dev.2', '0.20.0-dev.4'), isFalse);
      expect(isPackageAtLeastVersion('0.20.0-dev.4', '0.20.0-dev.2'), isTrue);
      expect(isPackageAtLeastVersion('0.20.0-dev.9', '0.20.0-dev.10'), isFalse);
      expect(isPackageAtLeastVersion('0.20.0-dev.10', '0.20.0-dev.9'), isTrue);
    });

    test('a version neither side can parse as semver answers false rather '
        'than throwing', () {
      expect(isPackageAtLeastVersion('not a version', '0.20.0'), isFalse);
      expect(isPackageAtLeastVersion('0.20.0', 'not a version'), isFalse);
    });
  });
}
