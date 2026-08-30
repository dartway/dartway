import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dw_check_type.dart';

/// Verifies that the app's localization is actually wired.
///
/// The law says every project is localized and user-visible text is never
/// written in code. Until now nothing checked it, and the gap is not
/// theoretical: one application had no `l10n/`, no `.arb`, no
/// `flutter_localizations` and not a single `context.l10n` — around 450 strings
/// written straight into 150 widget files. Nobody had broken a rule. The rule
/// used to describe a starting state, and a project that reached the
/// methodology by another road never had that state to lose.
///
/// **It is silent everywhere else.** The compiler is happy, the tests are
/// green, the app looks finished. What surfaced it was a person noticing one
/// Russian item in an otherwise English menu — because with no single place for
/// text, the language of a string is decided by whoever happens to type it.
///
/// An error rather than a warning, because the law's own wording is that this
/// is "the first thing fixed, not something to live with". A project created by
/// `dartway create` arrives with all of it, so the finding means the harness
/// was adopted by a project that did not.
///
/// The finding names **which pieces are missing**: "localization is not wired"
/// is not something anyone can act on, and the half-wired state — an `.arb`
/// with no `generate: true`, say — is the one that produces the strangest
/// errors.
class DwL10nWiringInspector {
  DwL10nWiringInspector({
    required this.flutterPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null || filterType == DwCheckType.l10nNotWired) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.l10nNotWired.severity);

  final Directory flutterPackageDir;

  final bool _enabled;
  final _findings = <String>[];

  /// The findings, in the order they were made. Exposed for the tests: the
  /// report is printed, the wording is the contract.
  List<String> get findings => List.unmodifiable(_findings);

  int run() {
    if (!_enabled) return 0;
    if (!Directory(p.join(flutterPackageDir.path, 'lib')).existsSync()) {
      return 0;
    }

    _findings.addAll(missingPieces(flutterPackageDir));
    if (_findings.isEmpty) return 0;

    print('\n🌍 Localization wiring:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.l10nNotWired.reportLabel}: $finding');
    }
    print(
      '\n  Every project is localized — that is a requirement, not a report on\n'
      '  how the project began. The skeleton ships all of the above; a project\n'
      '  that arrived by another road has to put it there, and doing it later\n'
      '  means walking every screen. See the Flutter section of CLAUDE.md.',
    );
    return _findings.length;
  }

  /// What the app is missing, as sentences. Empty means wired.
  ///
  /// Pure over the directory so the rule can be tested against a made-up
  /// package rather than against whatever the repository happens to contain.
  static List<String> missingPieces(Directory flutterPackageDir) {
    final missing = <String>[];
    final pubspecFile = File(p.join(flutterPackageDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return const [];

    final YamlMap? pubspec;
    try {
      final decoded = loadYaml(pubspecFile.readAsStringSync());
      pubspec = decoded is YamlMap ? decoded : null;
    } on YamlException {
      return const [];
    }
    if (pubspec == null) return const [];

    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap ||
        !dependencies.containsKey('flutter_localizations')) {
      missing.add(
        'pubspec.yaml does not depend on flutter_localizations '
        '(add it with `sdk: flutter`)',
      );
    }

    final flutterSection = pubspec['flutter'];
    if (flutterSection is! YamlMap || flutterSection['generate'] != true) {
      missing.add(
        'pubspec.yaml has no `generate: true` under `flutter:` — '
        'without it `flutter gen-l10n` produces nothing',
      );
    }

    if (!File(p.join(flutterPackageDir.path, 'l10n.yaml')).existsSync()) {
      missing.add('l10n.yaml is absent — nothing says where the .arb live');
    }

    final arbDir = Directory(p.join(flutterPackageDir.path, 'lib', 'l10n'));
    final arbFiles = arbDir.existsSync()
        ? arbDir
              .listSync()
              .whereType<File>()
              .where((file) => p.extension(file.path) == '.arb')
              .toList()
        : const <File>[];
    if (arbFiles.isEmpty) {
      missing.add('lib/l10n holds no .arb file — there is no catalogue');
    }

    return missing;
  }
}
