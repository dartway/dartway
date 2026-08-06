import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';
import 'dw_feature_tree.dart';

/// The zones of a Flutter app: the folders that hold features, and the only
/// ones asked for a `DwFeatureSpec`.
///
/// The list is closed on purpose. A fifth navigation zone does not earn a
/// folder of its own — it is a group inside `app/`, exactly like any other
/// group. What the top level answers is "what kind of thing is this", and the
/// answers are: the app, the admin panel, signing in, and the features more
/// than one of them draws on.
const dwFlutterZones = {'admin', 'app', 'auth', 'common'};

/// The layers of a Flutter app: everything that is not a feature.
///
/// `core/` is the app-wide wiring — the router, `DwCore.init`, app settings,
/// the Studio bridge binding. `shared/` holds building blocks: widgets and
/// helpers with no story of their own, extensions on models included. There is
/// deliberately no `data/` (the data layer is `dw.repo`) and no `domain/`
/// (in a DartWay app the rules live in CRUD configs on the server, and what is
/// left on the Flutter side is a helper).
const dwFlutterLayers = {'core', 'l10n', 'shared', 'ui_kit'};

/// The top level of a Serverpod package's `lib/src/`.
///
/// The boundary that matters here: **domain** — pure rules over models, no
/// `Session`/IO/DB; **app** — session-aware workflows that span models. Neither
/// ships in the skeleton, because until such code exists the folder is empty.
const dwServerAreas = {
  'app',
  'crud',
  'dartway',
  'domain',
  'endpoints',
  'generated',
  'models',
  'web',
};

/// Validates the declared top level of a DartWay project: the folders that may
/// exist, and the files that must.
///
/// The other checks judge what is inside a feature; this one judges where the
/// feature is. It exists because the layout had been declared in three places
/// at once — the docs, the agent toolkit and this checker — and the three had
/// drifted apart, which is how the admin panel came to live inside `app/`.
/// A structure nothing verifies is a structure that is already wrong.
///
/// Legacy folders (`zarchive/` and friends) and dot-folders are passed over:
/// they are declared elsewhere as awaiting removal, and a rule that fires on
/// them teaches people to turn the rule off.
class DwLayoutInspector {
  DwLayoutInspector({
    required this.flutterPackageDir,
    this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.invalidTopLevelLayout) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.invalidTopLevelLayout.severity);

  final Directory flutterPackageDir;
  final Directory? serverPackageDir;

  final bool _enabled;
  final _findings = <String>[];

  /// The findings, in the order they were made. Exposed for the tests: the
  /// report is printed, but what the rule *said* is the thing worth asserting.
  List<String> get findings => List.unmodifiable(_findings);

  /// Runs the checks and prints the section. Returns the number of findings
  /// (all of them errors — the layout is either the declared one or not).
  int run() {
    if (!_enabled) return 0;

    _checkFlutterPackage();
    _checkServerPackage();

    if (_findings.isEmpty) return 0;

    print('\n🧭 Project layout:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.invalidTopLevelLayout.reportLabel}: $finding');
    }
    return _findings.length;
  }

  void _checkFlutterPackage() {
    final libDir = Directory(p.join(flutterPackageDir.path, 'lib'));
    if (!libDir.existsSync()) return;

    final packageName = _packageNameOf(flutterPackageDir);
    // `dartway create my_app` renames the template's `dartway_starter_app.dart`
    // along with the package, so the wiring file always carries the project's
    // name — it is a fixed name, not a free choice.
    final appFile = packageName.endsWith('_flutter')
        ? '${packageName.substring(0, packageName.length - '_flutter'.length)}'
              '_app.dart'
        : null;
    final allowedFiles = {'main.dart', if (appFile != null) appFile};

    _checkEntries(
      dir: libDir,
      label: '${p.basename(flutterPackageDir.path)}/lib',
      allowedFolders: {...dwFlutterZones, ...dwFlutterLayers},
      allowedFiles: allowedFiles,
      requiredEntries: allowedFiles,
      hint:
          'zones ${_sorted(dwFlutterZones)} · '
          'layers ${_sorted(dwFlutterLayers)}',
    );

    for (final zone in dwFlutterZones.followedBy(const ['shared'])) {
      _checkNoNestedTopLevelName(
        Directory(p.join(libDir.path, zone)),
        libDir,
      );
    }
  }

  /// A top-level name that has slid one level down. Nothing above catches it:
  /// a folder inside a zone is read as a group, so `app/admin/` compiles, runs
  /// and looks deliberate — which is exactly how the admin panel spent a
  /// release living inside `app/`. The names are reserved everywhere below a
  /// zone, so the one place `admin/` can mean the admin panel is the top.
  void _checkNoNestedTopLevelName(Directory dir, Directory libDir) {
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.') || dwIgnoredFolders.contains(name)) continue;

      if (dwFlutterZones.contains(name) || dwFlutterLayers.contains(name)) {
        final rel = p
            .relative(entity.path, from: libDir.path)
            .replaceAll(r'\', '/');
        _findings.add(
          'lib/$rel — `$name` is a top-level name, and this one sits inside '
          'a zone, where it reads as an ordinary group. Move it to lib/$name',
        );
        continue;
      }

      _checkNoNestedTopLevelName(entity, libDir);
    }
  }

  void _checkServerPackage() {
    final serverDir = serverPackageDir;
    if (serverDir == null) return;

    final libDir = Directory(p.join(serverDir.path, 'lib'));
    if (!libDir.existsSync()) return;

    _checkEntries(
      dir: libDir,
      label: '${p.basename(serverDir.path)}/lib',
      allowedFolders: {'src'},
      allowedFiles: {'server.dart'},
      requiredEntries: {'server.dart', 'src'},
      hint: 'the package exposes server.dart and keeps the rest in src/',
    );

    final srcDir = Directory(p.join(libDir.path, 'src'));
    if (!srcDir.existsSync()) return;

    _checkEntries(
      dir: srcDir,
      label: '${p.basename(serverDir.path)}/lib/src',
      allowedFolders: dwServerAreas,
      allowedFiles: const {},
      requiredEntries: const {},
      hint: _sorted(dwServerAreas),
    );
  }

  /// One pass over a directory: nothing beyond [allowedFolders] /
  /// [allowedFiles] may be there, and everything in [requiredEntries] must be.
  void _checkEntries({
    required Directory dir,
    required String label,
    required Set<String> allowedFolders,
    required Set<String> allowedFiles,
    required Set<String> requiredEntries,
    required String hint,
  }) {
    final present = <String>{};

    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (name.startsWith('.') || dwIgnoredFolders.contains(name)) {
        // `l10n/` is on the ignore list (it is generated output, not a feature
        // tree) yet is a declared layer, so it still counts as present.
        present.add(name);
        continue;
      }
      present.add(name);

      final isFolder = entity is Directory;
      final allowed = isFolder ? allowedFolders : allowedFiles;
      if (allowed.contains(name)) continue;

      _findings.add(
        '$label/$name is not part of the declared layout — $hint',
      );
    }

    for (final required in requiredEntries) {
      if (present.contains(required)) continue;
      _findings.add('$label/$required is missing — it is a fixed name');
    }
  }

  static String _sorted(Set<String> names) =>
      (names.toList()..sort()).join(' ');

  static String _packageNameOf(Directory packageDir) {
    final pubspec = File(p.join(packageDir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return '';
    final match = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    return match?.group(1) ?? '';
  }
}
