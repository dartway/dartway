import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'monorepo_source.dart';
import 'project_layout.dart';
import 'toolkit_installer.dart';
import 'toolkit_manifest.dart';

/// The install options `setup-ai` and `update` share.
///
/// Declared once because the two commands install the same thing: an option
/// that existed on one of them only would be a setting a project can state and
/// then silently lose on the next run through the other door.
void addToolkitInstallOptions(
  ArgParser parser, {
  required String defaultChannel,
}) {
  parser
    ..addOption(
      'base-branch',
      defaultsTo: 'master',
      help: 'Base branch of THIS project (used by PR/commit skills).',
    )
    ..addOption(
      'language',
      defaultsTo: 'English',
      help:
          "Language this project writes its own texts in (feature specs, doc "
          "comments, docs/dev_notes/). Package APIs and error strings stay "
          "English regardless.",
    )
    ..addOption(
      'notes-tracker',
      valueHelp: 'owner/repo',
      defaultsTo: ProjectLayout.defaultNotesTracker,
      help:
          'GitHub repository where findings about the framework are filed as '
          'issues. Pass "${ProjectLayout.noNotesTracker}" to file nothing '
          'outside this project — findings then go to docs/dev_notes/.',
    )
    ..addOption(
      'channel',
      defaultsTo: defaultChannel,
      help: 'DartWay monorepo branch to take the toolkit from.',
    )
    ..addOption(
      'local-repo',
      help:
          'Path to a local DartWay monorepo checkout '
          '(skips clone; also read from DARTWAY_MONOREPO_DIR).',
    );
}

/// What this install run was told, after the flags and what the project already
/// recorded have been reconciled.
class ToolkitInstallChoice {
  ToolkitInstallChoice({
    required this.baseBranch,
    required this.language,
    required this.notesTracker,
    required this.channel,
    required this.localRepo,
    required this.channelWasExplicit,
  });

  /// Resolves the three settings in one place, and the order is the point:
  /// **an explicit flag wins, what the project recorded comes next, the
  /// option's default comes last.**
  ///
  /// Without the middle step a plain re-run resets a project's language, base
  /// branch and notes tracker to the defaults — and the diff of that reset is
  /// indistinguishable from the diff of an ordinary update, which is what makes
  /// it worth code rather than a note in the docs. It went unnoticed for as
  /// long as re-installing was a rare, deliberate act; `update` is meant to be
  /// run without arguments, and would have made it routine.
  ///
  /// [followRecordedChannel] extends the same order to the channel, and only
  /// `update` asks for it: "update" means move forward on the channel this
  /// project is on, while `setup-ai` keeps the default it always had — with
  /// [channelSwitchRefusal] behind it to stop that default from carrying a
  /// project backwards without being asked.
  factory ToolkitInstallChoice.resolve({
    required ArgResults args,
    required ToolkitProvenance? installed,
    bool followRecordedChannel = false,
  }) {
    String pick(String flag, String settingKey) => args.wasParsed(flag)
        ? args[flag] as String
        : (installed?.setting(settingKey) ?? args[flag] as String);

    return ToolkitInstallChoice(
      baseBranch: pick('base-branch', ToolkitProvenance.baseBranchSetting),
      language: pick('language', ToolkitProvenance.languageSetting),
      notesTracker: pick(
        'notes-tracker',
        ToolkitProvenance.notesTrackerSetting,
      ),
      channel: (followRecordedChannel && !args.wasParsed('channel'))
          ? (installed?.channel ?? args['channel'] as String)
          : args['channel'] as String,
      localRepo: args['local-repo'] as String?,
      channelWasExplicit: args.wasParsed('channel'),
    );
  }

  final String baseBranch;
  final String language;
  final String notesTracker;
  final String channel;
  final String? localRepo;
  final bool channelWasExplicit;

  Map<String, String> get settings => {
    ToolkitProvenance.baseBranchSetting: baseBranch,
    ToolkitProvenance.languageSetting: language,
    ToolkitProvenance.notesTrackerSetting: notesTracker,
  };

  void describe(StringSink out) {
    out.writeln('Base branch: $baseBranch');
    out.writeln('Project language: $language');
    out.writeln(
      notesTracker == ProjectLayout.noNotesTracker
          ? 'Notes tracker: none — the journal stays local'
          : 'Notes tracker: $notesTracker',
    );
  }
}

class ToolkitInstallResult {
  ToolkitInstallResult({required this.monorepoDir, required this.provenance});

  /// The resolved monorepo checkout — what the toolkit was taken from, and what
  /// the rest of an update reads its versions and migration notes out of.
  final Directory monorepoDir;

  final ToolkitProvenance provenance;
}

/// Installs `.claude/` into [projectRoot], or returns null having explained on
/// stderr why it must not.
Future<ToolkitInstallResult?> installToolkitInto({
  required Directory projectRoot,
  required ToolkitInstallChoice choice,
  required ToolkitProvenance? installed,
}) async {
  final layout = ProjectLayout.detect(projectRoot);
  stdout.writeln(
    'Packages: server=${layout.serverPackage} '
    'flutter=${layout.flutterPackage} '
    'client=${layout.clientPackage} '
    'shared=${layout.sharedPackage ?? '<none>'}',
  );
  choice.describe(stdout);

  final source = MonorepoSource(
    branch: choice.channel,
    localDir: choice.localRepo,
  );

  // Before anything is fetched: a channel switch nobody asked for is the one
  // way this can move a project backwards, and it costs nothing to notice here
  // rather than after the clone.
  final refusal = channelSwitchRefusal(
    installed: installed,
    requestedChannel: choice.channel,
    channelWasExplicit: choice.channelWasExplicit,
    fromLocalCheckout: source.isLocalCheckout,
  );
  if (refusal != null) {
    stderr.writeln(refusal);
    return null;
  }

  final monorepoDir = await source.resolve();
  final provenance = await source.provenance(
    monorepoDir,
    settings: choice.settings,
  );

  await ToolkitInstaller.install(
    toolkitDir: Directory(p.join(monorepoDir.path, 'toolkit')),
    projectRoot: projectRoot,
    tokens: layout.toolkitTokens(
      baseBranch: choice.baseBranch,
      language: choice.language,
      notesTracker: choice.notesTracker,
    ),
    provenance: provenance,
  );

  return ToolkitInstallResult(monorepoDir: monorepoDir, provenance: provenance);
}
