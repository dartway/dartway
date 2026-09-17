import 'dart:io';

import 'package:path/path.dart' as p;

/// The one language a new project's app speaks, chosen by
/// `dartway create --language`.
///
/// The skeleton carries every translation it has (`lib/l10n/app_<code>.arb`);
/// a project keeps one. A second language is a deliberate act: every string in
/// an ARB nobody reads is written twice from the first day, and the copy
/// drifts silently. The kept one becomes the template ARB and the app's
/// stated `productLocale`, so nothing about the device decides it (#230).
class ProjectLocale {
  const ProjectLocale._();

  static const _names = {'english': 'en', 'russian': 'ru', 'русский': 'ru'};

  /// The language code [language] names: a two-letter code as given, or a
  /// language's name; null when it names none.
  static String? codeOf(String language) {
    final value = language.trim().toLowerCase();
    if (RegExp(r'^[a-z]{2}$').hasMatch(value)) return value;
    return _names[value];
  }

  /// Keeps only [language]'s translation in the app package [flutterPackage]
  /// and regenerates the localizations. Answers what the caller should tell
  /// the person, or an empty list when nothing needs saying.
  static List<String> apply(Directory flutterPackage, String language) {
    final l10n = Directory(p.join(flutterPackage.path, 'lib', 'l10n'));
    final available = {
      for (final file in l10n.listSync().whereType<File>())
        if (RegExp(r'^app_([a-z]{2})\.arb$').firstMatch(p.basename(file.path))
            case final match?)
          match.group(1)!: file,
    };
    final notices = <String>[];
    var code = codeOf(language);
    if (code == null || !available.containsKey(code)) {
      notices.add(
        'The skeleton has no ${code ?? '"$language"'} translation '
        '(it has ${(available.keys.toList()..sort()).join(', ')}); the app '
        'starts in English. Add lib/l10n/app_<code>.arb, make it '
        'template-arb-file in l10n.yaml and set '
        'AppLocaleController.productLocale.',
      );
      code = 'en';
    }

    for (final MapEntry(key: other, value: arb) in available.entries) {
      if (other == code) continue;
      arb.deleteSync();
      final generated = File(
        p.join(l10n.path, 'gen', 'app_localizations_$other.dart'),
      );
      if (generated.existsSync()) generated.deleteSync();
    }

    final config = File(p.join(flutterPackage.path, 'l10n.yaml'));
    config.writeAsStringSync(
      config.readAsStringSync().replaceFirst(
        RegExp(r'template-arb-file:.*'),
        'template-arb-file: app_$code.arb',
      ),
    );

    final controller = File(
      p.join(flutterPackage.path, 'lib', 'core', 'app_l10n.dart'),
    );
    controller.writeAsStringSync(
      controller.readAsStringSync().replaceFirst(
        RegExp(r"static const Locale productLocale = Locale\('[a-z]{2}'\);"),
        "static const Locale productLocale = Locale('$code');",
      ),
    );

    final ProcessResult result;
    try {
      result = Process.runSync(
        'flutter',
        ['gen-l10n'],
        workingDirectory: flutterPackage.path,
        runInShell: true,
      );
    } on ProcessException {
      return [...notices, _regenerate];
    }
    if (result.exitCode != 0) return [...notices, _regenerate];
    return notices;
  }

  static const _regenerate =
      'Could not run `flutter gen-l10n`: run it in the app package before the '
      'first build — lib/l10n/gen still lists the translations that were '
      'removed.';
}
