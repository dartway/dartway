import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// The synchronisation law's own item 6 (root `CLAUDE.md`): a package's
/// `CHANGELOG.md` names the version it is about to publish. `--cut`
/// deliberately never writes this heading (`release_cut.dart`) — it is
/// human text — so this check is what tells a maintainer to add it, instead
/// of `dart pub publish --force` shipping a changelog that still describes
/// the previous version (review of PR #358, N3).
void main() {
  group('topChangelogVersion', () {
    test('reads a bare ## heading', () {
      expect(topChangelogVersion('## 0.21.0\n\n- notes\n'), '0.21.0');
    });

    test('an optional # Changelog title above it is not itself an entry', () {
      expect(
        topChangelogVersion('# Changelog\n\n## 0.6.0\n\n- notes\n'),
        '0.6.0',
      );
    });

    test('a dated heading reads only the version token', () {
      expect(
        topChangelogVersion('## 2.0.0 - 2026-09-23\n\n### Breaking\n'),
        '2.0.0',
      );
    });

    test('null when the file has no ## heading at all', () {
      expect(topChangelogVersion('# Changelog\n\nnothing here yet\n'), isNull);
    });

    test('only the first heading counts — earlier entries are history', () {
      expect(
        topChangelogVersion('## 0.6.0\n\n- notes\n\n## 0.5.0\n\n- older\n'),
        '0.6.0',
      );
    });
  });

  group('changelogMismatch', () {
    test('null when the top entry names the version being published', () {
      expect(changelogMismatch('## 0.21.0\n\n- notes\n', '0.21.0'), isNull);
    });

    test('names both versions when they disagree', () {
      final problem = changelogMismatch(
        '## 0.21.0-dev.6\n\n- notes\n',
        '0.21.0',
      );
      expect(problem, isNotNull);
      expect(problem, contains('0.21.0-dev.6'));
      expect(problem, contains('0.21.0'));
    });

    test('an empty changelog is a mismatch, not a pass', () {
      expect(changelogMismatch('', '0.21.0'), isNotNull);
    });
  });
}
