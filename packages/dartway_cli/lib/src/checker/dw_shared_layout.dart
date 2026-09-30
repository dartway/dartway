import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_layout.dart';

/// The project-named files at the top of a shared package's `lib/src/`:
/// `<prefix>_<role>.dart`, the prefix the package's name without `_shared`
/// (`acme_shared` → `acme_channel.dart`). Each is the project's answer to one
/// of the framework's package-wide roles — the channels, the refusal codes,
/// the upload purposes, the protocol the two sides speak, the push
/// categories — the shared half of what the server keeps in `core/`.
const dwSharedPackageRoles = [
  'channel',
  'refusal',
  'upload',
  'protocol',
  'push_category',
];

/// The top level of a shared package's `lib/`: the library a package is named
/// for, what the generator writes, and everything else under `src/`.
const dwSharedLibFolders = {'generated', 'src'};

/// The prefix of a shared package's project-named files: its name without
/// `_shared`.
String dwSharedPrefix(String packageName) => packageName.endsWith('_shared')
    ? packageName.substring(0, packageName.length - '_shared'.length)
    : packageName;

/// Whether [fileName] is `<feature>.dart` or `<feature>_<part>.dart`, the only
/// names inside a shared feature folder `src/<feature>/`. A part is never a
/// layer's name (`chat_models.dart`): a feature splits by what it is about.
bool dwIsSharedFeatureFile(String feature, String fileName) {
  if (fileName == '$feature.dart') return true;
  final match = RegExp(
    '^${RegExp.escape(feature)}_([a-z][a-z0-9_]*)\\.dart\$',
  ).firstMatch(fileName);
  if (match == null) return false;
  return !match.group(1)!.split('_').any(dwServerForbiddenFolders.contains);
}

/// The shared package mirrors the server's features
/// ([DwCheckType.invalidSharedLayout], dartway/dartway#383).
///
/// `lib/src/` holds `<feature>.dart` or a folder `<feature>/` of
/// `<feature>.dart` and `<feature>_<part>.dart` files, `<feature>` the name of
/// a feature folder of the server's `lib/src/`, and the project-named files of
/// [dwSharedPackageRoles] — nothing else. `lib/` itself holds the package's
/// library, `generated/` and `src/`.
///
/// Every project had grown its own shared layout — flat area files beside
/// folders named after nothing on the server, a data object of one feature
/// kept in another's file, a 2400-line file of 76 types — so "where is the
/// contract of this feature" had as many answers as projects. With the server
/// as the list, it has one, and the checker reads both packages to hold it.
class DwSharedLayoutInspector {
  DwSharedLayoutInspector({
    required this.sharedPackageDir,
    this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.invalidSharedLayout) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.invalidSharedLayout.severity);

  final Directory? sharedPackageDir;

  /// Where the feature names are read; without it, names are not matched.
  final Directory? serverPackageDir;

  final bool _enabled;
  final _findings = <String>[];

  /// The findings, in the order they were made.
  List<String> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    final shared = sharedPackageDir;
    if (!_enabled || shared == null) return 0;
    final lib = Directory(p.join(shared.path, 'lib'));
    if (!lib.existsSync()) return 0;

    final packageName = _packageNameOf(shared);
    final label = '${p.basename(shared.path)}/lib';
    _checkLib(lib, label, packageName);

    final src = Directory(p.join(lib.path, 'src'));
    final features = _serverFeatures();
    if (src.existsSync()) {
      _checkSrc(src, '$label/src', dwSharedPrefix(packageName), features);
    }

    // Said rather than passed over: without the server, a shared file named
    // after nothing would pass, and a clean run would claim otherwise.
    if (features == null) {
      print(
        '\n  ℹ️ INFO: shared file names not matched to server features: '
        'no server package found',
      );
    }
    if (_findings.isEmpty) return 0;
    print('\n🧩 Shared package layout:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.invalidSharedLayout.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.invalidSharedLayout, _findings.length);
    return _findings.length;
  }

  /// The server's feature folders, or null without a server package.
  List<String>? _serverFeatures() {
    final server = serverPackageDir;
    if (server == null) return null;
    final src = Directory(p.join(server.path, 'lib', 'src'));
    if (!src.existsSync()) return null;
    return [
      for (final entity in src.listSync())
        if (entity is Directory)
          if (p.basename(entity.path) case final name
              when !name.startsWith('.') &&
                  !dwServerSrcLayers.contains(name) &&
                  !dwServerForbiddenFolders.contains(name) &&
                  RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name))
            name,
    ]..sort();
  }

  void _checkLib(Directory lib, String label, String packageName) {
    final library = '$packageName.dart';
    var hasLibrary = false;
    for (final entity in _sorted(lib)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory
          ? dwSharedLibFolders.contains(name)
          : name == library) {
        if (name == library) hasLibrary = true;
        continue;
      }
      _findings.add(
        '$label/$name is not part of the declared layout — the package '
        'exposes $library, the generator writes generated/, and the rest '
        'lives in src/',
      );
    }
    if (!hasLibrary && packageName.isNotEmpty) {
      _findings.add('$label/$library is missing — it is a fixed name');
    }
  }

  void _checkSrc(
    Directory src,
    String label,
    String prefix,
    List<String>? features,
  ) {
    final roleFiles = {
      for (final role in dwSharedPackageRoles) '${prefix}_$role.dart',
    };
    final entries = _sorted(src);
    final folders = {
      for (final entity in entries)
        if (entity is Directory) p.basename(entity.path),
    };
    bool isFeature(String name) =>
        features?.contains(name) ?? RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
    final featureList = features == null
        ? '<feature>'
        : features.isEmpty
        ? 'the server declares none'
        : 'the server\'s: ${features.join(', ')}';

    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        if (isFeature(name)) {
          _checkFeatureFolder(entity, name, '$label/$name');
        } else {
          _findings.add(
            '$label/$name/ is not a feature of the server ($featureList) — '
            '${_fixFor(name, features, prefix)}',
          );
        }
        continue;
      }
      // A generated part is named after its source, and moves with it.
      if (name.endsWith('.dw.dart')) continue;
      if (roleFiles.contains(name)) continue;
      if (!name.endsWith('.dart')) {
        _findings.add(
          '$label/$name — src/ holds Dart files only; move it out of lib/',
        );
        continue;
      }
      final stem = name.substring(0, name.length - '.dart'.length);
      if (isFeature(stem)) {
        if (folders.contains(stem)) {
          _findings.add(
            '$label/$name beside $label/$stem/ — a feature is one file or '
            'one folder: move it to $label/$stem/$name',
          );
        }
        continue;
      }
      _findings.add(
        '$label/$name is neither a feature of the server ($featureList) nor '
        'one of ${roleFiles.join(', ')} — ${_fixFor(stem, features, prefix)}',
      );
    }
  }

  void _checkFeatureFolder(Directory dir, String feature, String label) {
    for (final entity in _sorted(dir)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        _findings.add(
          '$label/$name/ — a shared feature folder is flat; its files are '
          '$feature.dart and ${feature}_<part>.dart',
        );
        continue;
      }
      if (name.endsWith('.dw.dart')) continue;
      if (dwIsSharedFeatureFile(feature, name)) continue;
      final stem = name.endsWith('.dart')
          ? name.substring(0, name.length - '.dart'.length)
          : name;
      final topic = _topic(stem, feature);
      _findings.add(
        '$label/$name — not $feature.dart or ${feature}_<part>.dart (a part '
        'is what the file is about, never a layer: '
        '${(dwServerForbiddenFolders.toList()..sort()).join(', ')})'
        '${topic.isEmpty ? '' : ': rename it to ${feature}_$topic.dart'}',
      );
    }
  }

  /// Where a shared file or folder named [stem] that is no feature goes.
  String _fixFor(String stem, List<String>? features, String prefix) {
    for (final role in dwSharedPackageRoles) {
      if (stem == role || stem.endsWith('_$role')) {
        return 'rename it to ${prefix}_$role.dart';
      }
    }
    if (stem.startsWith('${prefix}_')) {
      return 'the project-named files are '
          '${dwSharedPackageRoles.map((r) => '${prefix}_$r.dart').join(', ')}; '
          'anything else goes with the feature that owns it';
    }
    final owner = _nearestFeature(stem, features);
    if (owner != null) {
      final topic = _topic(stem, owner);
      if (topic.isEmpty) return 'rename it to src/$owner.dart';
      return 'it belongs to $owner: src/$owner/${owner}_$topic.dart '
          '(with src/$owner.dart moved to src/$owner/$owner.dart)';
    }
    return 'move what it declares to the feature that owns it — '
        'src/<feature>.dart, or src/<feature>/<feature>_<part>.dart';
  }

  /// The feature whose name [stem] starts with, or a near miss of it
  /// (`issue_process` for `issues`, `course` for `courses`).
  static String? _nearestFeature(String stem, List<String>? features) {
    if (features == null) return null;
    final first = stem.split('_').first;
    for (final feature in features) {
      if (stem.startsWith('${feature}_')) return feature;
    }
    for (final feature in features) {
      if (first.isNotEmpty &&
          (feature.startsWith(first) || first.startsWith(feature))) {
        return feature;
      }
    }
    return null;
  }

  /// What [stem] is about without [feature]'s prefix, or a near miss of it,
  /// and without a layer's name.
  static String _topic(String stem, String feature) {
    var segments = stem.split('_');
    if (stem == feature) return '';
    if (stem.startsWith('${feature}_')) {
      segments = stem.substring(feature.length + 1).split('_');
    } else if (segments.first.isNotEmpty &&
        (feature.startsWith(segments.first) ||
            segments.first.startsWith(feature))) {
      segments = segments.sublist(1);
    }
    return segments
        .where((s) => s.isNotEmpty && !dwServerForbiddenFolders.contains(s))
        .join('_');
  }

  static String _packageNameOf(Directory packageDir) {
    final pubspec = File(p.join(packageDir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final match = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync());
      if (match != null) return match.group(1)!;
    }
    return p.basename(packageDir.path);
  }

  static List<FileSystemEntity> _sorted(Directory dir) =>
      dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
}
