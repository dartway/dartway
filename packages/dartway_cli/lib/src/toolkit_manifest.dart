import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The version of this CLI, as a constant the code can read.
///
/// A copy of what `pubspec.yaml` says, because a compiled or globally activated
/// executable has no reliable way back to its own pubspec. It is a checked
/// copy: `cli_version_test.dart` compares the two and goes red when they part.
const dartwayCliVersion = '0.10.0';

/// Where an installed harness came from.
///
/// The installed files do not say. They are the toolkit's files, so comparing
/// them against the current toolkit answers *"is this behind"* — but not *"which
/// channel is it from"*, and that is the question with teeth: `--channel`
/// defaults to `stable`, so a project deliberately moved to `master` is rolled
/// back by the next plain `dartway setup-ai`, and the diff of that rollback
/// looks exactly like the diff of an ordinary update.
///
/// So this records **provenance, not content**. A list of installed files or
/// their hashes would be a second copy of the files themselves, and copies of
/// files are what drift; where they came from is not written down anywhere else.
class ToolkitProvenance {
  const ToolkitProvenance({
    required this.source,
    required this.channel,
    required this.commit,
    required this.cliVersion,
    required this.installedAt,
    this.settings = const {},
  });

  /// The install settings worth remembering: the three that come from a flag
  /// and cannot be detected from the tree.
  ///
  /// Named here rather than at each call site because the writer and the reader
  /// have to agree on the spelling, and a key misspelled on one side of that
  /// pair fails as a silently defaulted setting.
  static const baseBranchSetting = 'baseBranch';
  static const languageSetting = 'language';
  static const notesTrackerSetting = 'notesTracker';

  /// Reads the manifest a previous install left, or null when there is none —
  /// which is every project installed before this existed.
  static ToolkitProvenance? read(Directory projectRoot) {
    final file = _fileIn(projectRoot);
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return null;
      final settings = decoded['settings'];
      return ToolkitProvenance(
        source: decoded['source'] as String? ?? '?',
        channel: decoded['channel'] as String?,
        commit: decoded['commit'] as String?,
        cliVersion: decoded['cliVersion'] as String? ?? '?',
        installedAt: decoded['installedAt'] as String? ?? '?',
        settings: settings is Map
            ? {
                for (final entry in settings.entries)
                  if (entry.key is String && entry.value is String)
                    entry.key as String: entry.value as String,
              }
            : const {},
      );
    } on FormatException {
      return null;
    }
  }

  /// The repository the toolkit was taken from, or the path of a local checkout
  /// when the framework itself was being worked on.
  final String source;

  /// The branch, or null when the source was a local checkout — a working
  /// directory's branch says nothing about what a project should follow.
  final String? channel;

  /// The commit the toolkit was read at, or null when it could not be resolved.
  final String? commit;

  final String cliVersion;
  final String installedAt;

  /// What the install was told, in the terms of the flags that said it.
  ///
  /// The package names are re-detected on every run and are therefore not kept;
  /// these three are choices, and a choice that is not written down is a choice
  /// the next run makes again from its defaults. `dartway update` exists to be
  /// run without arguments, so without this it would quietly reset a project's
  /// language, base branch and notes tracker — an update that silently undoes a
  /// decision is worse than no update command at all.
  final Map<String, String> settings;

  String? setting(String key) {
    final value = settings[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  static File _fileIn(Directory projectRoot) =>
      File(p.join(projectRoot.path, '.claude', 'dartway-toolkit.json'));

  void write(Directory projectRoot) {
    _fileIn(projectRoot).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'source': source, if (channel != null) 'channel': channel, if (commit != null) 'commit': commit, 'cliVersion': cliVersion, 'installedAt': installedAt, if (settings.isNotEmpty) 'settings': settings})}\n',
    );
  }

  /// One line for the install output — what was put in, in the terms someone
  /// would use to ask for it again.
  String describe() {
    final where = channel != null ? '$source@$channel' : source;
    final short = commit == null
        ? null
        : commit!.substring(0, commit!.length < 7 ? commit!.length : 7);
    final at = short != null ? ' ($short)' : '';
    return '$where$at, installed by dartway $cliVersion';
  }
}

/// The commit a monorepo checkout is at, or null when it cannot be read.
///
/// Null is an ordinary answer rather than a failure: the cache is cloned with
/// `--depth 1` and a local checkout is whatever the developer has, so the
/// manifest records what it can and says nothing it cannot stand behind.
Future<String?> monorepoCommit(Directory monorepoDir) async {
  try {
    final result = await Process.run('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: monorepoDir.path);
    if (result.exitCode != 0) return null;
    final commit = (result.stdout as String).trim();
    return commit.isEmpty ? null : commit;
  } on ProcessException {
    return null;
  }
}

/// Why an install must not go ahead, or null when it may.
///
/// The only case, and it is the one that happens: the project records one
/// channel and the command is about to install another **without having been
/// asked to**. `--channel` defaults to `stable`, so this is what a plain
/// `dartway setup-ai` does to a project that was deliberately moved to
/// `master` — and the resulting diff is indistinguishable from an update.
///
/// Refusing rather than prompting is deliberate: it works the same when nobody
/// is at the terminal, and the escape — naming the channel — leaves the
/// decision written down in the command that was run.
String? channelSwitchRefusal({
  required ToolkitProvenance? installed,
  required String requestedChannel,
  required bool channelWasExplicit,
  required bool fromLocalCheckout,
}) {
  // A local checkout ignores the channel entirely — `MonorepoSource` resolves
  // to the directory it was handed — and the install that follows records no
  // channel. Judging it against the `--channel` default would block the
  // framework's own development loop (`dartway setup-ai --local-repo ../dartway`)
  // for any project whose harness came from a non-default channel, over a
  // channel the run was never going to touch.
  if (fromLocalCheckout) return null;

  final recorded = installed?.channel;
  if (recorded == null || channelWasExplicit) return null;
  if (recorded == requestedChannel) return null;
  return 'This project has the toolkit from the "$recorded" channel, and the '
      'command would install "$requestedChannel" — the default. Moving between '
      'channels is a decision, and it can move a project backwards, so it is '
      'not something a default should make.\n'
      'Run it again naming the channel you mean: '
      '--channel $recorded to stay, --channel $requestedChannel to switch.';
}
