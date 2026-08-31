// Are the local git settings the constitution states actually set?
//
// `CLAUDE.md` used to say, as a statement of fact: "Locally: `fetch.prune=true`,
// `pull.rebase=true`, `rerere.enabled=true`." It was not one. These live in
// `.git/config`, per clone and per machine; they do not travel with the code,
// so cloning the repository and reading that sentence gave you a repository
// that did not do what the sentence said, with nothing anywhere setting them or
// noticing they were missing.
//
// The cost is the quiet kind. Without `fetch.prune` a remote-tracking ref
// survives the branch it tracks — `deleteBranchOnMerge` is on and GitHub does
// delete them, but a clone that never prunes keeps showing them, and they read
// as unfinished work, because that is exactly what an unmerged branch looks
// like. Three were investigated one at a time before it became clear all three
// had been merged and the refs were simply dead.
//
// Usage: dart run tool/git_config_check.dart   (from the repository root)

import 'dart:io';

import 'check_result.dart';

/// The settings `CLAUDE.md` states, and why each is worth a line.
const _expected = <String, ({String value, String because})>{
  'fetch.prune': (value: 'true', because: 'dead remote refs stop piling up'),
  'pull.rebase': (value: 'true', because: 'no merge commits from a pull'),
  'rerere.enabled': (
    value: 'true',
    because: 'a conflict resolved once is remembered',
  ),
};

void main() {
  final report = checkGitConfig();
  report.findings.forEach(stdout.writeln);
  stdout.writeln(report.summary);
  if (report.exitCode != 0) exit(report.exitCode);
}

CheckReport checkGitConfig() {
  const title = 'git settings';

  if (!Directory('.git').existsSync() && !File('.git').existsSync()) {
    return const CheckReport.unavailable(
      title,
      'No .git here — run this from the repository root.',
    );
  }

  final findings = <String>[];
  for (final entry in _expected.entries) {
    final actual = _configured(entry.key);
    if (actual == entry.value.value) continue;
    findings.add(
      '${entry.key} is ${actual == null ? 'not set' : actual} — '
      'want ${entry.value.value} (${entry.value.because}); '
      'fix: git config ${entry.key} ${entry.value.value}',
    );
  }

  if (findings.isEmpty) {
    return const CheckReport.ok(
      title,
      '✓ this clone has the git settings CLAUDE.md states',
    );
  }
  return CheckReport.findings(
    title,
    findings,
    '${findings.length} of ${_expected.length} git settings are not what '
    'CLAUDE.md says they are. They are per-clone and per-machine: setting them '
    'here does not set them for anyone else.',
  );
}

/// `null` when the key is unset. `git config --get` exits 1 for that, which is
/// not an error and must not be reported as one.
String? _configured(String key) {
  final result = Process.runSync('git', ['config', '--get', key]);
  if (result.exitCode != 0) return null;
  return (result.stdout as String).trim();
}
