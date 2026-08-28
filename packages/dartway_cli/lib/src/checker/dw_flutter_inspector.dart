import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';
import 'dw_feature_tree.dart';
import 'dw_layout.dart';
import 'dw_unused_feature_files.dart';

/// Line-length model: nothing is said below 200 lines, >200 is a nudge
/// (info) and >350 a warning.
///
/// The thresholds were deliberately relaxed: length is the weakest signal the
/// checker has, and a tight limit makes it lie. A file now also carries the
/// feature's `DwFeatureSpec` — a good description costs twenty lines, and a
/// rule that flags a well-described feature teaches people to describe less.
const dwFileLongThreshold = 200;
const dwFileTooLongThreshold = 350;

/// Areas whose folders must be shaped as features — and are asked for a
/// `DwFeatureSpec`. Exactly the zones of [dwFlutterZones], by name: the top
/// level is a closed list, so a prefix match would only let an undeclared
/// folder in through the side door.
///
/// `shared/` is deliberately absent: it holds building blocks, and a block has
/// no product behaviour to describe. Asking it for a spec is what produced
/// passports that only restate the class name, and a spec nobody believes is
/// worse than none.
bool _isFeatureArea(String name) => dwFlutterZones.contains(name);

/// Areas whose files are read for the cleanliness and UI-Kit rules.
///
/// A superset of [_isFeatureArea]: a raw `TextStyle` in a shared widget is as
/// wrong as one in `app/`, and until these two lists were told apart, moving a
/// widget out of a zone moved it out of every check at once.
///
/// Still not everything — `core/` is skipped entirely. That is a known gap,
/// and widening it is an open decision rather than an oversight to fix in
/// passing.
bool _isCheckedArea(String name) => _isFeatureArea(name) || name == 'shared';

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

  /// The kinds of finding this run made. Exposed for the tests, the same way
  /// [DwLayoutInspector] exposes its findings: the report is printed, but what
  /// the rule *said* is the thing worth asserting.
  Set<DwCheckType> get findingTypes => _stats.keys.toSet();

  /// What this run actually said, in order. Exposed for the tests alongside
  /// [findingTypes]: a diagnostic that names no destination leaves the author
  /// to find the intended shape by moving files until the rule stops firing,
  /// and that half of a check is only assertable on its text.
  List<String> get findingMessages => [
    for (final finding in _findings) finding.message,
  ];

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
      if (_isFeatureArea(area)) {
        for (final node in nodes) {
          _checkStructure(node, scope);
        }
        _checkUnusedFiles(nodes, scope);
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
        _checkFeatureEntryPoint(node, rel);
      }
    }

    for (final child in node.children) {
      _checkStructure(child, scope);
    }
  }

  /// What a feature's entry point has to be, read from both ends.
  ///
  /// A zone holds features and nothing else, so a folder in one whose entry
  /// point declares no widget is not a feature — and a folder that does declare
  /// one owes a `DwFeatureSpec`. Those are the same rule, and until both were
  /// checked each covered for the other's absence: a provider-only folder was
  /// silently accepted *because* it was not a widget.
  ///
  /// The widget test asks whether a **public class extends anything named
  /// `*Widget`**, rather than matching a list of base classes. The list was
  /// `(Stateless|Stateful|Consumer|HookConsumer|Hook)Widget` and quietly missed
  /// `ConsumerStatefulWidget` — the base class of every form and dialog, which
  /// is to say the features with the most behaviour to describe. A list of
  /// remembered names goes stale in silence; a shape does not.
  void _checkFeatureEntryPoint(DwFeatureNode node, String rel) {
    final entry = node.entryFile;
    if (entry == null) return;

    final content = entry.readAsStringSync();
    final declaresPublicWidget = RegExp(
      r'class\s+[A-Z]\w*\s+extends\s+\w*Widget\b',
    ).hasMatch(content);

    if (!declaresPublicWidget) {
      _add(
        DwCheckType.notAFeature,
        '$rel — a zone holds features, and this entry point declares no '
        'widget. State that several features watch is wiring and belongs in '
        'lib/core/; a helper with no story of its own is a building block and '
        'belongs in lib/shared/',
        rel,
      );
      return;
    }

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

  /// Dead code inside features: a file in `widgets/`/`logic/` that nothing in
  /// its own feature mentions. Reported against the feature, because that is
  /// where the decision to delete it gets made.
  void _checkUnusedFiles(List<DwFeatureNode> nodes, String? scope) {
    for (final feature in featuresIn(nodes)) {
      final owner = _libRelative(feature.dir.path);
      if (scope != null && owner != scope && !owner.startsWith('$scope/')) {
        continue;
      }

      for (final unused in findUnusedFeatureFiles(feature)) {
        _add(
          DwCheckType.unusedFeatureFile,
          '${_libRelative(unused.file.path)} is referenced by nothing in '
          '$owner (${unused.declaredNames.join(', ')}) — nobody outside the '
          'feature may import it, so this is dead code the compiler cannot '
          'see. Delete it, or move it to where its caller can reach it: a '
          'building block with no story of its own to lib/shared/, wiring '
          'several features share to lib/core/, a platform trio '
          '(x.dart + x_stub.dart + x_web.dart) to lib/core/platform/',
          owner,
        );
      }
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
      if (!_isCheckedArea(p.posix.split(rel).first)) continue;
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
    _checkBarrelFile(rel, content, owner);
    _checkWidgetSizesItself(rel, content, owner);
  }

  /// A file whose whole body is `export` directives.
  ///
  /// Detected by what is left after comments, blank lines and directives are
  /// removed: nothing but exports means the file carries no code of its own.
  /// A single-line re-export of one symbol counts too — that is the same hole,
  /// just smaller.
  void _checkBarrelFile(String rel, String content, String owner) {
    var exportCount = 0;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('//') ||
          trimmed.startsWith('/*') ||
          trimmed.startsWith('*')) {
        continue;
      }
      if (trimmed.startsWith('export ')) {
        exportCount++;
        continue;
      }
      return; // real code — not a barrel
    }

    if (exportCount == 0) return;

    _add(
      DwCheckType.barrelFile,
      '$rel only re-exports ($exportCount export'
      '${exportCount == 1 ? '' : 's'}) — import the real files instead; a '
      'barrel hides which feature an import actually reaches into',
      owner,
    );
  }

  /// `Expanded` or `SizedBox.expand` opening a `build` body.
  ///
  /// Matched on the return that follows a `build` signature, so a legitimate
  /// `Expanded` deeper in the tree — inside a `Column` the widget itself
  /// builds — is not touched.
  ///
  /// Deliberately narrow. A bare `SizedBox(width: double.infinity)` was tried
  /// here and taken back out: inside a bounded parent it only means "as wide as
  /// allowed", so every hit was arguable — and a check whose findings are
  /// arguable teaches people to skip the checker. These two are not arguable:
  /// both throw in the first parent that does not offer unbounded space.
  void _checkWidgetSizesItself(String rel, String content, String owner) {
    final rootReturn = RegExp(
      r'Widget\s+build\s*\([^)]*\)\s*(?:\{\s*return\s+|=>\s*)'
      r'(Expanded|SizedBox\.expand)\s*\(',
      dotAll: true,
    );

    for (final match in rootReturn.allMatches(content)) {
      _add(
        DwCheckType.widgetSizesItself,
        '$rel returns ${match.group(1)} from build — the widget decides how '
        'much room it gets, and breaks in the first parent that is not a flex; '
        'let the caller wrap it',
        owner,
      );
    }
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
      //
      // Only inside a feature area, though: `widgets/`/`logic/` are a feature's
      // shape, and `lib/shared/` holds no features. Its inner layout is the
      // project's business, so `shared/widgets/…` is a public path, not the
      // internals of anything.
      if (!_isFeatureArea(p.posix.split(target).first)) continue;
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
      _checkUiKitConstStyles(rel, content);
      _checkAssetPaths(rel, content, 'ui_kit');
    }
  }

  /// `static const Color` / `static const TextStyle` in the kit.
  ///
  /// Exempt: `ui_kit/theme/`, which is where the theme is assembled — a seed
  /// colour or a base style has to be written down somewhere, and that is the
  /// one place it does not depend on a context. Everything else in the kit is
  /// a consumer, and a consumer holding its own constant is the token that
  /// will not survive a second theme.
  void _checkUiKitConstStyles(String rel, String content) {
    if (rel.startsWith('ui_kit/theme/')) return;

    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('//') || line.startsWith('*')) continue;

      // Trimmed, so an indented member matches; a declaration wrapped across
      // lines by the formatter is missed, as in the text-constant rule beside
      // it — the same trade, and the same reason: a line is a shape a regex
      // can judge, and a parse is not what this checker is.
      final match = _uiKitConstStyle.firstMatch(line);
      if (match == null) continue;

      _add(
        DwCheckType.uiKitConstStyle,
        '$rel declares a const ${match.group(1)} (line ${i + 1}) — '
            'it will not follow a second theme; take it from '
            'Theme.of(context) through the palette instead',
        'ui_kit',
      );
      // One finding per file: the rest are the same mistake, and a list of
      // forty is a list nobody reads to the end.
      return;
    }
  }

  void _checkUiKitTextConstants(String rel, String content) {
    final lines = content.split('\n');
    var insideFallbackList = false;

    outer:
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // A string inside a comment is prose, not a text constant — usage examples
      // in doc comments are the most useful thing a kit widget can carry, and
      // flagging them taught authors to write worse documentation.
      if (line.startsWith('//') || line.startsWith('*')) continue;

      final openedFallbackList = insideFallbackList;
      insideFallbackList = _fontFallbackListContinues(line, insideFallbackList);

      for (final match in _uiKitTextLiteral.allMatches(line)) {
        // A typeface is not a label: nobody reads `'monospace'`, it is never
        // translated, and the kit is exactly where a font belongs — so there
        // is nowhere the rule could ask for it to be moved. Only the literals
        // in that position are exempt; a real label on the same line is still
        // a label that leaked into the kit.
        if (_isFontFamilyLiteral(line, match.start, openedFallbackList)) {
          continue;
        }

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
          break outer;
        }

        // Only the first literal of a line is judged — the rest of the line is
        // the same expression, and one finding per file is the report anyway.
        break;
      }
    }
  }

  /// Whether the literal starting at [start] names a typeface: it either sits
  /// directly in the `fontFamily` argument, or inside a `fontFamilyFallback`
  /// list — one that opened earlier on this line, or on an earlier one
  /// ([insideFallbackList]).
  bool _isFontFamilyLiteral(String line, int start, bool insideFallbackList) {
    if (insideFallbackList) {
      // The list came from an earlier line, so there is no `[` on this one to
      // measure against — the exemption ends at the `]` instead. Without that
      // column a line closing the list carries the exemption over everything
      // written after it, and a label sharing that line stops being reported.
      final closes = _maskLiterals(line).indexOf(']');
      return closes < 0 || start < closes;
    }
    final before = line.substring(0, start);
    return _fontFamilyArgument.hasMatch(before) ||
        _fontFamilyFallbackOpen.hasMatch(before);
  }

  /// [line] with every string literal blanked out, so a bracket written
  /// inside one is not read as code. Each literal is replaced by as many
  /// characters as it had: the exemption is measured in columns, and a mask
  /// that shortened the line would move them.
  static String _maskLiterals(String line) => line.replaceAllMapped(
    _uiKitTextLiteral,
    (match) => '_' * match.group(0)!.length,
  );

  /// Whether a `fontFamilyFallback: [...]` list is still open after [line].
  /// `dart format` breaks a long fallback list across lines, so the exemption
  /// has to survive the line ends.
  bool _fontFallbackListContinues(String line, bool wasOpen) {
    final code = _maskLiterals(line);
    if (wasOpen) return !code.contains(']');

    final at = code.indexOf('fontFamilyFallback');
    if (at < 0) return false;

    final tail = code.substring(at);
    return tail.contains('[') && !tail.contains(']');
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

    // The verdict is not printed here. This inspector knows its own findings
    // and nothing about the layout check that ran before it, and printing
    // "No errors" from inside it is how the report came to contradict the exit
    // code: two layout errors on screen, "check passes" underneath, and a
    // process exiting 1. Whoever counts both says it.
    return _stats.entries
        .where((entry) => entry.key.severity == DwCheckSeverity.error)
        .fold(0, (sum, entry) => sum + entry.value);
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

/// A quoted run of at least three characters — what the kit rule reads as a
/// candidate text constant.
final _uiKitTextLiteral = RegExp('''["']([^"']{3,})["']''');

/// A `static const` declaration that mentions a colour or a text style.
///
/// Not just `static const Color x` — the type is usually inferred
/// (`static const muted = Color(0xFF888888)`), and a palette is as often a
/// `Map<String, Color>`. All three are the same mistake, so the rule asks
/// whether the line declares a const and names the type anywhere in it.
///
/// `\bColor\b` rather than `Color`: `iconColor` is a name, not a type, and a
/// rule that reported it would be narrowed within a week.
final _uiKitConstStyle = RegExp(
  r'^static\s+const\b.*\b(Color|TextStyle)\b',
);

/// `fontFamily: 'monospace'` — the literal sits directly in that argument.
final _fontFamilyArgument = RegExp(r'\bfontFamily\s*:\s*(?:const\s+)?$');

/// A literal inside a `fontFamilyFallback: [...]` list opened on the same line.
final _fontFamilyFallbackOpen = RegExp(
  r'\bfontFamilyFallback\s*:[^\]]*\[[^\]]*$',
);
