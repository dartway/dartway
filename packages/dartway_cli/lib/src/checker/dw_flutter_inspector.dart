import 'dart:io';

import 'dw_check_type.dart';

/// Line-length model: >120 lines is undesirable (info), >200 is a warning.
const dwFileLongThreshold = 120;
const dwFileTooLongThreshold = 200;

/// DartWay convention checker for a Flutter package. Runs against
/// [packageDir] (the Flutter package root containing `lib/`).
///
/// Findings are reported per severity; the run fails (non-zero result) only
/// when errors are present — warnings and infos never fail CI.
class DwFlutterInspector {
  DwFlutterInspector({
    required this.packageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
  }) : activeTypes = DwCheckType.values
            .where((type) {
              if (filterType != null) return type == filterType;
              if (filterSeverity != null) {
                return type.severity == filterSeverity;
              }
              return true;
            })
            .toSet();

  final Directory packageDir;
  final Set<DwCheckType> activeTypes;

  /// When set, only this folder is validated (relative to [packageDir]).
  final String? targetDirPath;

  final _findings = <String>[];
  final _stats = <DwCheckType, int>{};

  /// Runs the checks and prints the report. Returns the number of
  /// error-severity findings (0 = the check passes).
  Future<int> run() async {
    print('Checking for ${activeTypes.map((t) => t.name).join(', ')}');

    if (targetDirPath != null) {
      final dir = Directory(_resolve(targetDirPath!));
      if (!dir.existsSync()) {
        print('❌ Selected folder not found: $targetDirPath');
        return 1;
      }
      await _validateFeatureRecursively(dir);
    } else {
      await _checkUiKit();
      await _checkFeatureRoots();
    }

    if (_findings.isEmpty) {
      print('✅ Flutter package passed all the checks');
      return 0;
    }

    print('\nFindings (${_findings.length}):\n');
    for (final finding in _findings) {
      print('- $finding');
    }

    print('\n📊 By check:');
    for (final entry in _stats.entries) {
      print(
        '• [${entry.key.severity.name.toUpperCase()}] ${entry.key.name} — ${entry.value}',
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

  String _resolve(String relative) =>
      relative.startsWith(RegExp(r'([A-Za-z]:)?[/\\]'))
          ? relative
          : '${packageDir.path}${Platform.pathSeparator}$relative';

  void _report(DwCheckType type, String message) {
    _findings.add('${type.reportLabel}: $message');
    _stats[type] = (_stats[type] ?? 0) + 1;
  }

  Future<void> _checkUiKit() async {
    final uiKitDir = Directory(_resolve('lib/ui_kit'));
    if (!uiKitDir.existsSync()) return;

    final files = uiKitDir.listSync(recursive: true).whereType<File>().where(
          (f) => f.path.endsWith('.dart') && !f.path.endsWith('ui_kit.dart'),
        );

    for (final file in files) {
      final content = await file.readAsString();

      if (activeTypes.contains(DwCheckType.uiKitPartMissing)) {
        final partOfDirective =
            RegExp("part of ['\"](../)+ui_kit.dart['\"];");
        if (!partOfDirective.hasMatch(content)) {
          _report(
            DwCheckType.uiKitPartMissing,
            'File ${file.path} in ui_kit does not contain '
            '"part of \'../ui_kit.dart\'" directive',
          );
        }
      }

      if (activeTypes.contains(DwCheckType.uiKitContainsText)) {
        _checkUiKitTextConstants(file.path, content);
      }
    }
  }

  void _checkUiKitTextConstants(String filePath, String content) {
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match =
          RegExp('''["']([^"']{3,})["']''').firstMatch(lines[i].trim());
      if (match == null) continue;

      final value = match.group(1);
      // Skip paths, translations, interpolations, date formats and the like.
      final isException = value == null ||
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
        _report(
          DwCheckType.uiKitContainsText,
          'File $filePath contains text constant: "$value" (line ${i + 1})',
        );
        break;
      }
    }
  }

  Future<void> _checkFeatureRoots() async {
    final libDir = Directory(_resolve('lib'));
    if (!libDir.existsSync()) return;

    final rootDirs = libDir.listSync().whereType<Directory>().where((d) {
      final name = d.path.split(Platform.pathSeparator).last;
      return name.startsWith('app') ||
          name.startsWith('auth') ||
          name.startsWith('common') ||
          name.startsWith('admin');
    });

    for (final dir in rootDirs) {
      await _validateFeatureRecursively(dir);
    }
  }

  Future<void> _validateFeatureRecursively(Directory dir) async {
    final pathParts = dir.path.split(Platform.pathSeparator);
    final name =
        pathParts.isNotEmpty ? pathParts.lastWhere((e) => e.isNotEmpty) : '';

    // Inside widgets/ and logic/ only per-file rules apply.
    if (name == 'logic' || name == 'widgets') {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in dartFiles) {
        _validateFileContent(file.path, await file.readAsString());
      }
      return;
    }

    final entries = dir.listSync();
    final rootDartFiles = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final subDirs = entries.whereType<Directory>().toList();

    if (activeTypes.contains(DwCheckType.invalidFeatureStructure)) {
      if (rootDartFiles.length > 1) {
        _report(
          DwCheckType.invalidFeatureStructure,
          '${dir.path} should contain only one .dart file (the root widget '
          'or extension that provides access to the feature)',
        );
      } else if (rootDartFiles.length == 1) {
        final invalidSubfolders = subDirs
            .map(
              (d) => d.path
                  .split(Platform.pathSeparator)
                  .lastWhere((e) => e.isNotEmpty),
            )
            .where((n) => n != 'widgets' && n != 'logic')
            .toList();

        if (invalidSubfolders.isNotEmpty) {
          _report(
            DwCheckType.invalidFeatureStructure,
            '${dir.path} contains inappropriate folders: '
            '${invalidSubfolders.join(', ')}',
          );
        }
      }
    }

    for (final file in rootDartFiles) {
      _validateFileContent(file.path, await file.readAsString());
    }

    for (final sub in subDirs) {
      await _validateFeatureRecursively(sub);
    }
  }

  void _validateFileContent(String filePath, String content) {
    if (filePath.endsWith('.g.dart') || filePath.endsWith('.freezed.dart')) {
      return; // generated files are exempt
    }

    final lineCount = content.split('\n').length;
    if (activeTypes.contains(DwCheckType.fileTooLong) &&
        lineCount > dwFileTooLongThreshold) {
      _report(
        DwCheckType.fileTooLong,
        '$filePath is $lineCount lines (>$dwFileTooLongThreshold) — '
        'worth restructuring',
      );
    } else if (activeTypes.contains(DwCheckType.fileLong) &&
        lineCount > dwFileLongThreshold) {
      _report(
        DwCheckType.fileLong,
        '$filePath is $lineCount lines (>$dwFileLongThreshold) — '
        'undesirable, not critical',
      );
    }

    if (activeTypes.contains(DwCheckType.forbiddenUiUsage)) {
      const forbiddenPatterns = {
        'Color(': 'Color',
        'TextStyle(': 'TextStyle',
        'BorderRadius.': 'BorderRadius',
        'BorderRadius(': 'BorderRadius',
        'context.textTheme': 'context.textTheme',
        'context.colorTheme': 'context.colorTheme',
        'context.colorScheme': 'context.colorScheme',
      };

      for (final entry in forbiddenPatterns.entries) {
        if (content.contains(entry.key)) {
          _report(
            DwCheckType.forbiddenUiUsage,
            '$filePath uses ${entry.value} directly '
            '(should be moved to ui_kit)',
          );
        }
      }
    }

    if (activeTypes.contains(DwCheckType.forbiddenUiKitImport)) {
      final uiKitImport = RegExp(
        r"import 'package:[^']*/ui_kit/([^']+)'",
        multiLine: true,
      );
      for (final match in uiKitImport.allMatches(content)) {
        final imported = match.group(1);
        if (imported != 'ui_kit.dart') {
          _report(
            DwCheckType.forbiddenUiKitImport,
            '$filePath imports ui_kit/$imported — import the ui_kit.dart '
            'barrel instead',
          );
        }
      }
    }

    if (activeTypes.contains(DwCheckType.forbiddenFeatureImport)) {
      final forbiddenImport = RegExp(
        r"import\s+'package:[^']*/(app|auth|common|admin)/([^/]+)/(widgets|logic)/",
      );

      // The feature this file belongs to.
      final parts = filePath.replaceAll('\\', '/').split('/');
      String? currentFeature;
      for (int i = parts.length - 1; i >= 2; i--) {
        if (parts[i] == 'widgets' || parts[i] == 'logic') {
          currentFeature = parts[i - 1];
          break;
        }
      }
      currentFeature ??= parts[parts.length - 2];

      for (final match in forbiddenImport.allMatches(content)) {
        final targetFeature = match.group(2);
        final segment = match.group(3);
        if (targetFeature != currentFeature) {
          _report(
            DwCheckType.forbiddenFeatureImport,
            '$filePath imports $segment from another feature $targetFeature',
          );
        }
      }
    }
  }
}
