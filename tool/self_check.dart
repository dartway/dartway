// One question, asked once: is what this repository says about itself true?
//
// Four times in a row the answer was no, in four different places — the
// lockfiles recorded a version the packages had left behind (#192), the carets
// stated a release that was never published (#143), the working tree rewrote
// files it had committed (#172), and `CLAUDE.md` described git settings a clone
// does not have (#170). Each was found by a person, late, and each was answered
// with a script of its own. A fourth separate script would have been the habit
// rather than the fix: three commands to remember, called one at a time, and a
// `framework-finish` growing a list.
//
// So the scripts stay one per subject — they are read when they fail, and a
// file per subject is what makes that readable — and the entry point is shared.
//
// Usage:
//   dart run tool/self_check.dart              every check
//   dart run tool/self_check.dart --offline    everything that needs no network
//
// Exit codes, aggregated: 0 all clean · 1 something is not what we say it is ·
// 2 nothing is wrong, but a check could not be carried out. The last is its own
// code for the reason `caret_check` gave it one — a check that could not run is
// not a check that failed, and reporting it as failure trains people to skim.

import 'dart:io';

import 'caret_check.dart';
import 'check_result.dart';
import 'git_config_check.dart';
import 'lock_check.dart';

void main(List<String> arguments) async {
  final unknown = arguments.where((a) => a != '--offline');
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument: ${unknown.first}');
    stderr.writeln('Usage: dart run tool/self_check.dart [--offline]');
    exit(64);
  }
  final offline = arguments.contains('--offline');

  final reports = <CheckReport>[checkGitConfig(), checkLockfiles()];
  if (!offline) reports.add(await checkCarets());

  for (final report in reports) {
    stdout.writeln('— ${report.title}');
    for (final finding in report.findings) {
      stdout.writeln('  $finding');
    }
    stdout.writeln('  ${report.summary}');
  }
  // Last, so the skipped check keeps the place it would have occupied. A note
  // that jumps to the top reads as something that happened first.
  if (offline) stdout.writeln('— carets against pub.dev: skipped (--offline)');

  final failed = reports.where((r) => r.outcome == CheckOutcome.findings);
  final unavailable = reports.where(
    (r) => r.outcome == CheckOutcome.unavailable,
  );

  stdout.writeln();
  if (failed.isEmpty && unavailable.isEmpty) {
    stdout.writeln('✓ the repository is what it says it is');
    return;
  }

  // Findings outrank an unavailable check: something being wrong is the more
  // useful of the two answers, and the summary above already named the one
  // that could not run.
  if (failed.isNotEmpty) {
    stdout.writeln(
      '✗ ${failed.length} of ${reports.length} checks found something: '
      '${failed.map((r) => r.title).join(', ')}',
    );
    exit(1);
  }
  stdout.writeln(
    '? ${unavailable.length} check${unavailable.length == 1 ? '' : 's'} could '
    'not be carried out: ${unavailable.map((r) => r.title).join(', ')}. '
    'Nothing is known to be wrong, and nothing is confirmed right either.',
  );
  exit(2);
}
