import 'dart:io';

import 'package:path/path.dart' as p;

import '../monorepo_source.dart';
import '../toolkit_manifest.dart';

/// The skeleton a project was created from, as that project's files: what
/// `dartway create` would have written at a project path, with the project's
/// names in place of the template's.
///
/// Read so a check can tell the project's own code from what it inherited — a
/// doc comment the skeleton wrote in English is the skeleton's, not a lapse
/// of a project that writes in Russian (dartway/dartway#391).
abstract interface class DwProjectTemplate {
  /// The template's text for the project file at [projectPath] (relative to
  /// the project root, `/`-separated), renamed as `create` renames it; null
  /// when the template has no such file.
  String? fileFor(String projectPath);

  /// Where the template was read from, for the report.
  String get description;

  /// The template recorded for the project at [projectRoot], whose packages
  /// are named `<baseName>_flutter` and so on, or null when no checkout of
  /// the framework is at hand.
  ///
  /// The checkout is the one the toolkit was installed from when the manifest
  /// names a local one, else the one this CLI runs from, else the cache
  /// `dartway create` and `update` clone into. The template is read at the
  /// commit the manifest records when that checkout has it, and as the
  /// checkout holds it otherwise.
  static DwProjectTemplate? forProject(Directory projectRoot, String baseName) {
    final provenance = ToolkitProvenance.read(projectRoot);
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final candidates = <String?>[
      provenance?.source,
      MonorepoSource.findCliCheckout()?.path,
      if (home != null) p.join(home, '.dartway', 'monorepo'),
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (!Directory(p.join(candidate, 'template')).existsSync()) continue;
      final commit = provenance?.commit;
      final hasCommit =
          commit != null &&
          Process.runSync('git', [
                '-C',
                candidate,
                'cat-file',
                '-e',
                '$commit^{commit}',
              ]).exitCode ==
              0;
      return _CheckoutTemplate(
        Directory(candidate),
        hasCommit ? commit : null,
        baseName,
      );
    }
    return null;
  }
}

/// The names `dartway create` replaces, in the order it replaces them.
Map<String, String> dwTemplateRenames(String baseName) {
  final words = baseName.split('_').where((word) => word.isNotEmpty);
  final pascal = words.map((w) => w[0].toUpperCase() + w.substring(1)).join();
  return {
    'dartway_starter': baseName,
    'DartwayStarter': pascal,
    'dartwayStarter': pascal[0].toLowerCase() + pascal.substring(1),
    'dartway-starter': baseName.replaceAll('_', '-'),
  };
}

final class _CheckoutTemplate implements DwProjectTemplate {
  _CheckoutTemplate(this.checkout, this.commit, this.baseName);

  final Directory checkout;
  final String? commit;
  final String baseName;
  final _cache = <String, String?>{};

  @override
  String get description =>
      'template/ of ${checkout.path}'
      '${commit == null ? '' : ' at ${commit!.substring(0, 8)}'}';

  @override
  String? fileFor(String projectPath) => _cache.putIfAbsent(projectPath, () {
    final templatePath = [
      'template',
      for (final segment in projectPath.split('/'))
        segment.replaceAll(baseName, 'dartway_starter'),
    ].join('/');
    final String? text;
    if (commit != null) {
      final shown = Process.runSync('git', [
        '-C',
        checkout.path,
        'show',
        '$commit:$templatePath',
      ]);
      text = shown.exitCode == 0 ? shown.stdout as String : null;
    } else {
      final file = File(p.join(checkout.path, templatePath));
      text = file.existsSync() ? file.readAsStringSync() : null;
    }
    if (text == null) return null;
    var renamed = text;
    for (final MapEntry(key: from, value: to) in dwTemplateRenames(
      baseName,
    ).entries) {
      renamed = renamed.replaceAll(from, to);
    }
    return renamed;
  });
}
