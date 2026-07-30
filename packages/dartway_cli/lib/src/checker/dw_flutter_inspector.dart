import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';
import 'dw_feature_tree.dart';

/// Line-length model: nothing is said below 200 lines, >200 is a nudge
/// (info) and >350 a warning.
///
/// The thresholds were deliberately relaxed: length is the weakest signal the
/// checker has, and a tight limit makes it lie. A file now also carries the
/// feature's `DwFeatureSpec` — a good description costs twenty lines, and a
/// rule that flags a well-described feature teaches people to describe less.
const dwFileLongThreshold = 200;
const dwFileTooLongThreshold = 350;

/// Areas whose folders are expected to be shaped as features. The remaining
/// areas (`core/`, `data/`, `domain/`) hold infrastructure with a shape of its
/// own, so only the file-level and import rules apply there.
bool _isStructuralArea(String name) =>
    name.startsWith('app') ||
    name.startsWith('auth') ||
    name.startsWith('common') ||
    name.startsWith('admin');

/// A single finding, attributed to the feature that owns the file.
class _Finding {
  _Finding(this.type, this.message, this.owner);

  final DwCheckType type;
  final String message;

  /// lib-relative path of the owning feature, or of the area when the file
  /// sits outside any feature.
  final String owner;
}

/// DartWay convention checker for a Flutter package. Runs against
/// [packageDir] (the Flutter package root containing `lib/`).
///
/// The report is organised per feature: every feature gets a grade, so a large
/// project reads as a list of features to fix rather than as a wall of lines.
class DwFlutterInspector {
  DwFlutterInspector({
    required this.packageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
  }) : activeTypes = DwCheckType.values.where((type) {
         if (filterType != null) return type == filterType;
         if (filterSeverity != null) {
           return type.severity == filterSeverity;
         }
         return true;
       }).toSet();

  final Directory packageDir;
  final Set<DwCheckType> activeTypes;

  /// When set, only this folder is validated (relative to [packageDir]).
  final String? targetDirPath;

  final _findings = <_Finding>[];
  final _stats = <DwCheckType, int>{};

  late final String _packageName = _readPackageName();

  String get _libPath => p.join(packageDir.path, 'lib');

  /// Runs the checks and prints the report. Returns the number of
  /// error-severity findings (0 = the check passes).
  Future<int> run() async {
    print('Checking for ${activeTypes.map((t) => t.name).join(', ')}');

    final libDir = Directory(_libPath);
    if (!libDir.existsSync()) {
      print('❌ No lib/ folder in ${packageDir.path}');
      return 1;
    }

    final scope = targetDirPath == null
        ? null
        : p
              .relative(_resolve(targetDirPath!), from: _libPath)
              .replaceAll(r'\', '/');
    if (scope != null && !Directory(_resolve(targetDirPath!)).existsSync()) {
      print('❌ Selected folder not found: $targetDirPath');
      return 1;
    }

    if (scope == null) await _checkUiKit();

    final areas =
        libDir
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .where(
              (name) => name != 'ui_kit' && !dwIgnoredFolders.contains(name),
            )
            .toList()
          ..sort();

    final trees = <String, List<DwFeatureNode>>{};
    for (final area in areas) {
      final nodes = buildAreaNodes(Directory(p.join(_libPath, area)));
      trees[area] = nodes;
      if (_isStructuralArea(area)) {
        for (final node in nodes) {
          _checkStructure(node, scope);
        }
      }
    }

    await _checkFiles(libDir, scope);

    return _report(trees, scope);
  }

  String _resolve(String relative) =>
      relative.startsWith(RegExp(r'([A-Za-z]:)?[/\\]'))
      ? relative
      : p.join(packageDir.path, relative);

  String _readPackageName() {
    final pubspec = File(p.join(packageDir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return '';
    final match = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    return match?.group(1) ?? '';
  }

  String _libRelative(String absolutePath) =>
      p.relative(absolutePath, from: _libPath).replaceAll(r'\', '/');

  void _add(DwCheckType type, String message, String owner) {
    if (!activeTypes.contains(type)) return;
    _findings.add(_Finding(type, message, owner));
    _stats[type] = (_stats[type] ?? 0) + 1;
  }

  // ---------------------------------------------------------------- structure

  void _checkStructure(DwFeatureNode node, String? scope) {
    final rel = _libRelative(node.dir.path);
    if (scope == null || rel == scope || rel.startsWith('$scope/')) {
      if (node.rootFiles.length > 1) {
        _add(
          DwCheckType.invalidFeatureStructure,
          '$rel has ${node.rootFiles.length} root files '
          '(${node.rootFiles.map((f) => p.basename(f.path)).join(', ')}) — '
          'a feature has exactly one public file; anything shared with a '
          'sibling belongs in a feature of its own',
          rel,
        );
      } else {
        _checkFeatureSpec(node, rel);
      }
    }

    for (final child in node.children) {
      _checkStructure(child, scope);
    }
  }

  /// A feature's public widget is expected to declare what the feature is —
  /// `implements DwFeature` with a `DwFeatureSpec`. Checked only for widgets:
  /// a feature whose entry point is an extension or a plain function has
  /// nothing to hang a spec on.
  void _checkFeatureSpec(DwFeatureNode node, String rel) {
    final entry = node.entryFile;
    if (entry == null) return;

    final content = entry.readAsStringSync();
    final isWidget = RegExp(
      r'extends\s+(Stateless|Stateful|Consumer|HookConsumer|Hook)Widget',
    ).hasMatch(content);
    if (!isWidget) return;

    if (!content.contains('DwFeature')) {
      _add(
        DwCheckType.featureSpecMissing,
        '$rel declares no DwFeatureSpec — the feature exists in the code but '
        'says nothing about itself (error reports, Studio and the agent all '
        'read that spec)',
        rel,
      );
    }
  }

  // -------------------------------------------------------------------- files

  Future<void> _checkFiles(Directory libDir, String? scope) async {
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final rel = _libRelative(file.path);
      if (rel.startsWith('ui_kit/')) continue;
      if (p.posix.split(rel).any(dwIgnoredFolders.contains)) continue;
      // Same scope the checker has always had: the feature-shaped areas.
      if (!_isStructuralArea(p.posix.split(rel).first)) continue;
      if (scope != null && !rel.startsWith('$scope/') && rel != scope) continue;
      _validateFileContent(rel, await file.readAsString());
    }
  }

  void _validateFileContent(String rel, String content) {
    if (rel.endsWith('.g.dart') ||
        rel.endsWith('.gen.dart') ||
        rel.endsWith('.freezed.dart')) {
      return; // generated files are nobody's code
    }

    final owner = ownerFeatureOf(rel) ?? p.posix.split(rel).first;

    final lineCount = content.split('\n').length;
    if (lineCount > dwFileTooLongThreshold) {
      _add(
        DwCheckType.fileTooLong,
        '$rel is $lineCount lines (>$dwFileTooLongThreshold) — '
        'worth restructuring',
        owner,
      );
    } else if (lineCount > dwFileLongThreshold) {
      _add(
        DwCheckType.fileLong,
        '$rel is $lineCount lines (>$dwFileLongThreshold) — '
        'undesirable, not critical',
        owner,
      );
    }

    const forbiddenPatterns = {
      'Color(': 'Color',
      'TextStyle(': 'TextStyle',
      'BorderRadius.': 'BorderRadius',
      'BorderRadius(': 'BorderRadius',
      'context.textTheme': 'context.textTheme',
      'context.colorTheme': 'context.colorTheme',
      'context.colorScheme': 'context.colorScheme',
      // The longhand of the three above. Without it the rule is trivially
      // sidestepped: `Theme.of(context).textTheme.bodySmall` reads as ordinary
      // Flutter and passed the checker while `context.textTheme` did not.
      'Theme.of(': 'Theme.of(context)',
      'context.theme': 'context.theme',
    };
    for (final entry in forbiddenPatterns.entries) {
      if (content.contains(entry.key)) {
        _add(
          DwCheckType.forbiddenUiUsage,
          '$rel uses ${entry.value} directly (should be moved to ui_kit)',
          owner,
        );
      }
    }

    _checkImports(rel, content, owner);
    _checkAssetPaths(rel, content, owner);
  }

  /// Asset paths are checked against the file system — this is what replaces
  /// the guarantee a code generator used to give: a generated constant could
  /// not name a file that does not exist, a hand-written one can.
  void _checkAssetPaths(String rel, String content, String owner) {
    final assetLiteral = RegExp(r"'(assets/[^']+)'");
    for (final match in assetLiteral.allMatches(content)) {
      final assetPath = match.group(1)!;

      if (!File(p.join(packageDir.path, assetPath)).existsSync()) {
        _add(
          DwCheckType.assetPathMissing,
          '$rel points at $assetPath, which does not exist',
          owner,
        );
      }

      if (!rel.startsWith('ui_kit/')) {
        _add(
          DwCheckType.forbiddenAssetPath,
          '$rel spells out $assetPath — asset paths belong to the kit, and '
          'the screen should receive a widget, not a file name',
          owner,
        );
      }
    }
  }

  void _checkImports(String rel, String content, String owner) {
    if (_packageName.isEmpty) return;

    final ownImport = RegExp(
      "import\\s+'package:$_packageName/([^']+)'",
      multiLine: true,
    );

    for (final match in ownImport.allMatches(content)) {
      final target = match.group(1)!;

      if (target.startsWith('ui_kit/')) {
        if (target != 'ui_kit/ui_kit.dart' && target != 'ui_kit.dart') {
          _add(
            DwCheckType.forbiddenUiKitImport,
            '$rel imports $target — import the ui_kit.dart barrel instead',
            owner,
          );
        }
        continue;
      }

      // Reaching into another feature's internals. Grouping folders do not
      // change visibility: what is forbidden is the `widgets/` and `logic/` of
      // a feature that is not the importer's own.
      if (!isFeatureInternalPath(target)) continue;
      final targetOwner = ownerFeatureOf(target);
      if (targetOwner == null || targetOwner == owner) continue;

      _add(
        DwCheckType.forbiddenFeatureImport,
        '$rel imports the internals of $targetOwner ($target) — only the '
        'public file of a feature may be imported from outside it',
        owner,
      );
    }
  }

  // ------------------------------------------------------------------- ui_kit

  Future<void> _checkUiKit() async {
    final uiKitDir = Directory(p.join(_libPath, 'ui_kit'));
    if (!uiKitDir.existsSync()) return;

    // Generated files are nobody's code: a `part of` directive added to
    // `assets.gen.dart` survives exactly until the next `flutter_gen` run, so
    // demanding one is demanding a chore that undoes itself.
    final files = uiKitDir
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('ui_kit.dart') &&
              !f.path.endsWith('.gen.dart') &&
              !f.path.endsWith('.g.dart') &&
              !f.path.endsWith('.freezed.dart'),
        );

    for (final file in files) {
      final content = await file.readAsString();
      final rel = _libRelative(file.path);

      final partOfDirective = RegExp("part of ['\"](../)+ui_kit.dart['\"];");
      if (!partOfDirective.hasMatch(content)) {
        _add(
          DwCheckType.uiKitPartMissing,
          '$rel does not contain "part of \'../ui_kit.dart\'" directive',
          'ui_kit',
        );
      }

      _checkUiKitTextConstants(rel, content);
      _checkAssetPaths(rel, content, 'ui_kit');
    }
  }

  void _checkUiKitTextConstants(String rel, String content) {
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // A string inside a comment is prose, not a text constant — usage examples
      // in doc comments are the most useful thing a kit widget can carry, and
      // flagging them taught authors to write worse documentation.
      if (line.startsWith('//') || line.startsWith('*')) continue;

      final match = RegExp('''["']([^"']{3,})["']''').firstMatch(line);
      if (match == null) continue;

      final value = match.group(1);
      // Skip paths, translations, interpolations, date formats and the like.
      final isException =
          value == null ||
          value.contains(RegExp(r'\.svg$|\.png$|\.dart$|\.json$')) ||
          value.startsWith('../') ||
          value.startsWith(r'$') ||
          value.startsWith(r'r$') ||
          value.contains('i18n') ||
          value.contains('.tr') ||
          value.contains('assets') ||
          value.contains('path') ||
          value.contains('svg') ||
          value.contains('AppText.') ||
          RegExp(r'^[dMyHms.:/\-\s]+$').hasMatch(value);

      if (!isException) {
        _add(
          DwCheckType.uiKitContainsText,
          '$rel contains text constant: "$value" (line ${i + 1})',
          'ui_kit',
        );
        break;
      }
    }
  }

  // ------------------------------------------------------------------ report

  int _report(Map<String, List<DwFeatureNode>> trees, String? scope) {
    final byOwner = <String, List<_Finding>>{};
    for (final finding in _findings) {
      byOwner.putIfAbsent(finding.owner, () => []).add(finding);
    }

    if (_findings.isEmpty) {
      print('✅ Flutter package passed all the checks');
      return 0;
    }

    print('\n📁 Features (grade · files · findings)\n');
    for (final area in trees.keys) {
      final nodes = trees[area]!;
      if (nodes.isEmpty && !byOwner.containsKey(area)) continue;
      print('$area/');
      for (final node in nodes) {
        _printNode(node, byOwner, 1, scope);
      }
      final areaLevel = byOwner[area];
      if (areaLevel != null) {
        print(
          '  ${_grade(areaLevel).badge}  (files directly in $area/) '
          '· ${_countsLabel(areaLevel)}',
        );
      }
    }

    print('\n🔍 Findings by feature:\n');
    final ownersWithFindings = byOwner.keys.toList()..sort();
    for (final owner in ownersWithFindings) {
      final findings = byOwner[owner]!;
      print('$owner — ${_countsLabel(findings)}');
      for (final finding in findings.take(6)) {
        print('  ${finding.type.reportLabel}: ${finding.message}');
      }
      if (findings.length > 6) {
        print('  … +${findings.length - 6} more');
      }
      print('');
    }

    print('📊 By check:');
    for (final entry in _stats.entries) {
      print(
        '• [${entry.key.severity.name.toUpperCase()}] ${entry.key.name} — '
        '${entry.value}',
      );
    }

    final errorCount = _stats.entries
        .where((entry) => entry.key.severity == DwCheckSeverity.error)
        .fold(0, (sum, entry) => sum + entry.value);
    if (errorCount > 0) {
      print('\n🔴 Errors: $errorCount (warnings/infos do not fail the check)');
    } else {
      print('\n🟡 No errors — only warnings/infos, check passes');
    }
    return errorCount;
  }

  void _printNode(
    DwFeatureNode node,
    Map<String, List<_Finding>> byOwner,
    int depth,
    String? scope,
  ) {
    final rel = _libRelative(node.dir.path);
    final indent = '  ' * depth;

    if (node.isGroup) {
      print('$indent${node.name}/ — group');
    } else {
      final findings = byOwner[rel] ?? const <_Finding>[];
      final grade = _grade(findings);
      final files = node.ownFiles.length;
      final suffix = findings.isEmpty ? '' : ' · ${_countsLabel(findings)}';
      print(
        '$indent${grade.badge} ${node.name.padRight(34 - indent.length)}'
        '${grade.letter}  $files file${files == 1 ? '' : 's'}$suffix',
      );
    }

    for (final child in node.children) {
      _printNode(child, byOwner, depth + 1, scope);
    }
  }

  String _countsLabel(List<_Finding> findings) {
    final errors = findings
        .where((f) => f.type.severity == DwCheckSeverity.error)
        .length;
    final warnings = findings
        .where((f) => f.type.severity == DwCheckSeverity.warning)
        .length;
    final infos = findings
        .where((f) => f.type.severity == DwCheckSeverity.info)
        .length;
    return [
      if (errors > 0) '$errors error${errors == 1 ? '' : 's'}',
      if (warnings > 0) '$warnings warning${warnings == 1 ? '' : 's'}',
      if (infos > 0) '$infos info',
    ].join(', ');
  }

  _DwGrade _grade(List<_Finding> findings) {
    final errors = findings
        .where((f) => f.type.severity == DwCheckSeverity.error)
        .length;
    final warnings = findings
        .where((f) => f.type.severity == DwCheckSeverity.warning)
        .length;
    if (errors == 0 && warnings == 0) return const _DwGrade('A', '✅');
    if (errors == 0) return const _DwGrade('B', '🟡');
    if (errors <= 2) return const _DwGrade('C', '🟠');
    return const _DwGrade('D', '🔴');
  }
}

/// Quality marker of a single feature.
class _DwGrade {
  const _DwGrade(this.letter, this.badge);

  final String letter;
  final String badge;
}
