import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// What `release.dart`'s `main` prints and exits with, pulled out of it so
/// "a partial release exits non-zero" and "the plan says how many first
/// publications it holds" are testable without shelling out to `dart pub
/// publish` or asking pub.dev anything (review of PR #358, N2).
void main() {
  group('firstPublicationsLine', () {
    test('null when the plan has no first publication at all', () {
      expect(firstPublicationsLine(0), isNull);
    });

    test('names the count, without a warning, at or under the daily cap', () {
      expect(
        firstPublicationsLine(3),
        '3 of these are first publications. pub.dev allows at most 12 in a '
        'day.',
      );
      expect(
        firstPublicationsLine(12),
        '12 of these are first publications. pub.dev allows at most 12 in a '
        'day.',
      );
    });

    test('warns once the count passes pub.dev\'s 12-a-day ceiling', () {
      expect(
        firstPublicationsLine(13),
        '13 of these are first publications. pub.dev allows at most 12 in a '
        'day — this plan has more than that and cannot all go out today.',
      );
    });
  });

  group('describePublishOutcome', () {
    test('a clean run — nothing deferred, nothing stopped — exits 0 (mutant: '
        'deleting this branch\'s exitCode: 0 must fail this)', () {
      final outcome = describePublishOutcome(
        const ReleasePublishReport(published: ['a', 'b'], deferred: {}),
        planNames: ['a', 'b'],
      );
      expect(outcome.exitCode, 0);
      expect(
        outcome.stdoutLines.join('\n'),
        contains('published 2 package(s)'),
      );
      expect(outcome.stderrLines, isEmpty);
    });

    test('any deferral exits non-zero and reports it as PARTIAL, even though '
        'nothing actually failed (mutant: deleting this exit(1) must fail '
        'this — review of PR #358, N2)', () {
      final outcome = describePublishOutcome(
        const ReleasePublishReport(
          published: ['a'],
          deferred: {'b': "pub.dev's daily package-created limit"},
        ),
        planNames: ['a', 'b'],
      );
      expect(outcome.exitCode, isNot(0));
      expect(outcome.stdoutLines.join('\n'), contains('PARTIAL'));
      expect(outcome.stdoutLines.join('\n'), contains('b'));
      expect(
        outcome.stdoutLines.join('\n'),
        contains("pub.dev's daily package-created limit"),
        reason:
            'the deferred package\'s own reason is printed, not just '
            'its name',
      );
    });

    test('a stop reports what published, what was deferred first, and what '
        'was never even attempted', () {
      final outcome = describePublishOutcome(
        const ReleasePublishReport(
          published: ['a'],
          deferred: {'b': 'daily limit'},
          stopped: (name: 'c', reason: 'boom: sdk constraint invalid'),
        ),
        planNames: ['a', 'b', 'c', 'd', 'e'],
      );
      expect(outcome.exitCode, isNot(0));
      final text = outcome.stderrLines.join('\n');
      expect(text, contains('c'));
      expect(text, contains('boom: sdk constraint invalid'));
      expect(text, contains('a'), reason: 'what published is named');
      expect(
        text,
        contains('b'),
        reason: 'what was deferred before the stop is named',
      );
      expect(
        text,
        contains('d'),
        reason:
            'd and e are neither published, deferred nor the stop '
            'itself — they were never attempted at all, and the report has '
            'to say so',
      );
      expect(text, contains('e'));
    });

    test("the failed package's own output is not duplicated: it appears once, "
        'as the stop reason, never a second time as a separate line (review '
        'of PR #358, N5)', () {
      final outcome = describePublishOutcome(
        const ReleasePublishReport(
          published: [],
          deferred: {},
          stopped: (name: 'a', reason: 'boom, only once'),
        ),
        planNames: ['a'],
      );
      final occurrences = 'boom, only once'
          .allMatches(outcome.stderrLines.join('\n'))
          .length;
      expect(occurrences, 1);
    });
  });
}
