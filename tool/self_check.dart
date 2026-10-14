// One question, asked once: is what this repository says about itself true?
//
// Lockfiles have recorded versions the packages had left behind (#192), the
// working tree has rewritten committed files (#172), and `AGENTS.md` describes
// git settings a clone does not have (#170). Each check stays readable in its
// own file, while this entry point asks them together.
//
// Usage:
//   dart run tool/self_check.dart              every check
//   dart run tool/self_check.dart --offline    everything that needs no network
//
// Exit codes, aggregated: 0 all clean · 1 a finding · 2 a check unavailable.

import 'dart:io';

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
  final reports = <CheckReport>[checkGitConfig(), checkLockfiles()];

  for (final report in reports) {
    stdout.writeln('— ${report.title}');
    for (final finding in report.findings) {
      stdout.writeln('  $finding');
    }
    stdout.writeln('  ${report.summary}');
  }
  final failed = reports.where((r) => r.outcome == CheckOutcome.findings);
  final unavailable = reports.where(
    (r) => r.outcome == CheckOutcome.unavailable,
  );
  stdout.writeln();
  if (failed.isEmpty && unavailable.isEmpty) {
    stdout.writeln('✓ the repository is what it says it is');
    return;
  }

  stdout.writeln(
    failed.isNotEmpty
        ? '✗ ${failed.length} of ${reports.length} checks found something: '
              '${failed.map((r) => r.title).join(', ')}'
        : '? ${unavailable.length} checks could not be carried out: '
              '${unavailable.map((r) => r.title).join(', ')}',
  );
  exit(failed.isNotEmpty ? 1 : 2);
}
