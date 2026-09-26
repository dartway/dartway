/// What `release.dart`'s `main` prints and exits with, once the plan and the
/// publish loop have answered — pulled out so "a partial release exits
/// non-zero" and "the plan says how many first publications it holds" are
/// facts a test can check without shelling out to `dart pub publish` or
/// asking pub.dev anything (review of PR #358, #313).
library;

import 'release_publish.dart';

/// The line the plan prints about first publications, or null when [count]
/// is zero.
///
/// pub.dev allows at most 12 `package-created` operations a day (#313); said
/// up front, since a plan with more cannot all go out in one calendar day
/// whatever `--publish` does about the rest of the order.
String? firstPublicationsLine(int count) {
  if (count == 0) return null;
  final warning = count > 12
      ? ' — this plan has more than that and cannot all go out today'
      : '';
  return '$count of these are first publications. pub.dev allows at most '
      '12 in a day$warning.';
}

/// What `main` prints and exits with, once `publishRelease` has answered.
class ReleasePublishOutcome {
  const ReleasePublishOutcome({
    required this.exitCode,
    required this.stdoutLines,
    required this.stderrLines,
  });

  /// 0 only when every plan entry actually published; 1 for a stop or any
  /// deferral — a partial release must never exit clean (#313).
  final int exitCode;
  final List<String> stdoutLines;
  final List<String> stderrLines;
}

/// Describes [report] for [planNames] — every package the plan named, in
/// order, used only to say which of them a stop left never even attempted.
ReleasePublishOutcome describePublishOutcome(
  ReleasePublishReport report, {
  required List<String> planNames,
}) {
  if (report.stopped case final stopped?) {
    final accountedFor = {
      stopped.name,
      ...report.published,
      ...report.deferred.keys,
    };
    final neverAttempted = planNames
        .where((name) => !accountedFor.contains(name))
        .toList();
    return ReleasePublishOutcome(
      exitCode: 1,
      stdoutLines: const [],
      stderrLines: [
        '✗ ${stopped.name} failed:',
        stopped.reason,
        '',
        'Stopping here: the packages after it in the order state carets on '
            'what did not go out.',
        'Published in this run: '
            '${report.published.isEmpty ? '(nothing)' : report.published.join(', ')}',
        if (report.deferred.isNotEmpty) ...[
          'Deferred before the stop:',
          for (final MapEntry(key: name, value: reason)
              in report.deferred.entries)
            '  - $name: $reason',
        ],
        if (neverAttempted.isNotEmpty)
          'Never attempted: ${neverAttempted.join(', ')}',
      ],
    );
  }

  if (report.deferred.isNotEmpty) {
    return ReleasePublishOutcome(
      exitCode: 1,
      stdoutLines: [
        '',
        "${report.deferred.length} package(s) deferred by pub.dev's "
            'package-created rate limit:',
        '',
        for (final MapEntry(key: name, value: reason)
            in report.deferred.entries)
          '  - $name: $reason',
        '',
        '✓ published ${report.published.length} of ${planNames.length} '
            'package(s) — the release is PARTIAL.',
      ],
      stderrLines: const [],
    );
  }

  return ReleasePublishOutcome(
    exitCode: 0,
    stdoutLines: [
      '',
      '✓ published ${report.published.length} package(s).',
      'The release is not finished: `stable` is moved by the promotion '
          'ritual in CLAUDE.md, not by this script.',
    ],
    stderrLines: const [],
  );
}
