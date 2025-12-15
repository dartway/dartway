import 'dart:io';

import 'dw_flutter_check_type.dart';

class DwFlutterInspector {
  late final Set<DwFlutterCheckType> activeTypes;
  late final String? dirPath;

  DwFlutterInspector(List<String> args) {
    DwFlutterCheckType? filterType;
    DwFlutterCheckSeverity? filterSeverity;
    String? argsDirPath;

    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--type' && i + 1 < args.length) {
        final typeArg = args[i + 1].toLowerCase();
        final match = DwFlutterCheckType.values.where(
          (e) => e.toString().split('.').last.toLowerCase() == typeArg,
        );
        if (match.isEmpty) {
          print('❌ Unknown check type: $typeArg');
          print('Known types:');
          for (var t in DwFlutterCheckType.values) {
            print(' - ${t.toString().split('.').last}');
          }
          exit(1);
        }
        filterType = match.first;
        i++;
      } else if (args[i] == '--level' && i + 1 < args.length) {
        final levelArg = args[i + 1];
        final match = DwFlutterCheckSeverity.values.where(
          (e) => e.toString().split('.').last == levelArg,
        );
        if (match.isEmpty) {
          print('❌ Unknown severity level: $levelArg');
          print('Supported levels: info, warning, error');
          exit(1);
        }
        filterSeverity = match.first;
        i++;
      } else if (args[i] == '--dir' && i + 1 < args.length) {
        argsDirPath = args[i + 1];
        i++;
      }
    }

    dirPath = argsDirPath;
    activeTypes = DwFlutterCheckType.values.where((t) {
      if (filterType != null) return t == filterType;
      if (filterSeverity != null) return t.severity == filterSeverity;
      return true;
    }).toSet();
  }

  Future<void> run() async {
    // Весь твой скрипт из main(), но вместо main() используй метод run().
    // Просто перенеси сюда твой код и используй this.args вместо args.
    // Например:
    final errors = <String>[];
    final errorStats = <DwFlutterCheckType, int>{};

    print("Checking for $activeTypes");

    if (dirPath != null) {
      final dir = Directory(dirPath!);
      if (!dir.existsSync()) {
        print('❌ Selected folder not found: $dirPath');
        exit(1);
      }
      await _validateFeatureRecursively(dir, errors, errorStats, activeTypes);
    } else {
      await checkUiKitParts(errors, errorStats, activeTypes);
      await checkFeatureCodeRules(errors, errorStats, activeTypes);
    }

    if (errors.isEmpty) {
      print('✅ Flutter Project passed all the checks');
    } else {
      print('\n❌ Following errors found: (${errors.length}):\n');
      for (final error in errors) {
        print('- $error');
      }

      print('\n📊 Error type stat:');
      for (final entry in errorStats.entries) {
        final type = entry.key;
        final count = entry.value;
        final label = type.toString().split('.').last;
        final severity = type.severity.name.toUpperCase();
        print('• [$severity] $label — $count');
      }

      print('\n🔴 Total errors: ${errors.length}');
      exit(1);
    }
  }

  void report(
    DwFlutterCheckType type,
    String message,
    List<String> errors,
    Map<DwFlutterCheckType, int> stats,
  ) {
    errors.add('${type.reportLabel}: $message');
    stats[type] = (stats[type] ?? 0) + 1;
  }

  Future<void> checkUiKitParts(
    List<String> errors,
    Map<DwFlutterCheckType, int> stats,
    Set<DwFlutterCheckType> activeTypes,
  ) async {
    final uiKitDir = Directory('lib/ui_kit');
    if (!uiKitDir.existsSync()) return;

    final files = uiKitDir.listSync(recursive: true).whereType<File>().where(
          (f) => f.path.endsWith('.dart') && !f.path.endsWith('ui_kit.dart'),
        );

    for (final file in files) {
      final content = await file.readAsString();
      if (activeTypes.contains(DwFlutterCheckType.uiKitContainsText)) {
// const regex = /part of ['"](\.\.\/)+ui_kit.dart['"];/gm;

        // Проверяем наличие директивы "part of ../ui_kit.dart"
        // Используем RegExp для проверки с учётом возможных кавычек и путей
        final regex = RegExp(r"part of [\x22\x27](../)+ui_kit.dart[\x22\x27];");

        if (!regex.hasMatch(content)) {
          report(
            DwFlutterCheckType.uiKitPartMissing,
            'File ${file.path} in ui_kit does not contain "part of ../ui_kit.dart" directive',
            errors,
            stats,
          );
        }

        // if (!content.contains("part of '../ui_kit.dart';")) {
        //   report(
        //     DwFlutterCheckType.uiKitPartMissing,
        //     'File ${file.path} in ui_kit does not contain "part of" directive',
        //     errors,
        //     stats,
        //   );
        // }
      }

      if (activeTypes.contains(DwFlutterCheckType.uiKitContainsText)) {
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          final match = RegExp(r'''["']([^"']{3,})["']''').firstMatch(line);

          if (match != null) {
            final value = match.group(1);

            // Игнорируем строки, которые похожи на пути, переводы, переменные и т.п.
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
                // value.length > 100 ||
                RegExp(
                  r'^[dMyHms.:/\-\s]+$',
                ).hasMatch(value); // формат даты или времени

            if (!isException) {
              report(
                DwFlutterCheckType.uiKitContainsText,
                'File ${file.path} contains text constant: "$value" (line ${i + 1})',
                errors,
                stats,
              );
              break;
            }
          }
        }
      }

      // if (activeTypes.contains(DwFlutterCheckType.uiKitContainsText)) {
      //   // Найдёт строки, содержащие хотя бы одну букву (русскую или латинскую) и пробел
      //   final textPattern = RegExp(r'''["']([^"']{3,})["']''');

      //   for (final match in textPattern.allMatches(content)) {
      //     final value = match.group(1);
      //     if (value != null &&
      //         value.contains(RegExp(
      //             r'[а-яА-Яa-zA-Z]')) && // чтобы отсеять пути, цифры и спецсимволы
      //         !value.contains(RegExp(r'\.tr\(|\.i18n')) &&
      //         !value.startsWith(r'$') &&
      //         !value.startsWith('../')) {
      //       report(
      //         DwFlutterCheckType.uiKitContainsText,
      //         'Файл ${file.path} содержит текстовую константу: "$value"',
      //         errors,
      //         stats,
      //       );
      //       break;
      //     }
      //   }
      // }
    }
  }

  Future<void> checkFeatureCodeRules(
    List<String> errors,
    Map<DwFlutterCheckType, int> stats,
    Set<DwFlutterCheckType> activeTypes,
  ) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return;

    final rootDirs = libDir.listSync().whereType<Directory>().where((d) {
      final name = d.path.split(Platform.pathSeparator).last;
      return name.startsWith('app') ||
          name.startsWith('auth') ||
          name.startsWith('common') ||
          name.startsWith('admin');
    }).toList();

    for (final dir in rootDirs) {
      await _validateFeatureRecursively(dir, errors, stats, activeTypes);
    }
  }

  Future<void> _validateFeatureRecursively(
    Directory dir,
    List<String> errors,
    Map<DwFlutterCheckType, int> stats,
    Set<DwFlutterCheckType> activeTypes,
  ) async {
    final pathParts = dir.path.split(Platform.pathSeparator);
    final name =
        pathParts.isNotEmpty ? pathParts.lastWhere((e) => e.isNotEmpty) : '';

    if (name == 'logic' || name == 'widgets') {
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in dartFiles) {
        final content = await file.readAsString();
        _validateFileContent(file.path, content, errors, stats, activeTypes);
      }
      return;
    }

    final entries = dir.listSync();
    final rootDartFiles = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final subDirs = entries.whereType<Directory>().toList();

    if (activeTypes.contains(DwFlutterCheckType.invalidFeatureStructure)) {
      if (rootDartFiles.length > 1) {
        report(
          DwFlutterCheckType.invalidFeatureStructure,
          '${dir.path} should contain only one .dart-файл (root widget or extension, which provides access to the feature)',
          errors,
          stats,
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
          report(
            DwFlutterCheckType.invalidFeatureStructure,
            '${dir.path} contains inappropriate folders: ${invalidSubfolders.join(', ')}',
            errors,
            stats,
          );
        }
      }
    }

    for (final file in rootDartFiles) {
      final content = await file.readAsString();
      _validateFileContent(file.path, content, errors, stats, activeTypes);
    }

    for (final sub in subDirs) {
      await _validateFeatureRecursively(sub, errors, stats, activeTypes);
    }
  }

  void _validateFileContent(
    String filePath,
    String content,
    List<String> errors,
    Map<DwFlutterCheckType, int> stats,
    Set<DwFlutterCheckType> activeTypes,
  ) {
    const maxLines = 150;

    if (filePath.endsWith('.g.dart') || filePath.endsWith('.freezed.dart')) {
      return; // пропускаем автогенерируемые файлы
    }

    if (activeTypes.contains(DwFlutterCheckType.fileTooLong)) {
      final lines = content.split('\n');
      if (lines.length > maxLines) {
        report(
          DwFlutterCheckType.fileTooLong,
          '$filePath is too long - ${lines.length} lines (recommended max is $maxLines))',
          errors,
          stats,
        );
      }
    }

    if (activeTypes.contains(DwFlutterCheckType.forbiddenUiUsage)) {
      final forbiddenPatterns = {
        'Color(': 'Color',
        'TextStyle(': 'TextStyle',
        'BorderRadius.': 'BorderRadius',
        'context.textTheme': 'context.textTheme',
        'context.colorTheme': 'context.colorTheme',
        'context.colorScheme': 'context.colorScheme',
      };

      for (final entry in forbiddenPatterns.entries) {
        if (content.contains(entry.key)) {
          report(
            DwFlutterCheckType.forbiddenUiUsage,
            '$filePath uses ${entry.value} directly (should be moved to ui_kit)',
            errors,
            stats,
          );
        }
      }
    }

    if (activeTypes.contains(DwFlutterCheckType.forbiddenUiKitImport)) {
      final uiKitImportRegex = RegExp(
        r"import 'package:[^']*/ui_kit/([^']+)'",
        multiLine: true,
      );
      for (final match in uiKitImportRegex.allMatches(content)) {
        final imported = match.group(1);
        if (imported != 'ui_kit.dart') {
          report(
            DwFlutterCheckType.forbiddenUiKitImport,
            '$filePath imports ui_kit/$imported while all files in ui_kit.dart should be included with "part of" directive',
            errors,
            stats,
          );
        }
      }
    }

    if (activeTypes.contains(DwFlutterCheckType.forbiddenFeatureImport)) {
      final forbiddenImportPattern = RegExp(
        r"import\s+'package:[^']*/(app|auth|common)/([^/]+)/(widgets|logic)/",
      );

      // Определяем имя фичи текущего файла
      final parts = filePath.replaceAll('\\', '/').split('/');
      String? currentFeature;
      for (int i = parts.length - 1; i >= 2; i--) {
        final part = parts[i];
        if (part == 'widgets' || part == 'logic') {
          currentFeature = parts[i - 1];
          break;
        }
      }
      currentFeature ??= parts[parts.length - 2];

      for (final match in forbiddenImportPattern.allMatches(content)) {
        final targetFeature = match.group(2);
        final segment = match.group(3);
        if (targetFeature != currentFeature) {
          report(
            DwFlutterCheckType.forbiddenFeatureImport,
            '$filePath imports $segment from another feature $targetFeature',
            errors,
            stats,
          );
        }
      }
    }
  }
}
