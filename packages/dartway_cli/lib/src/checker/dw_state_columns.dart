import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_outline.dart';
import 'dw_dart_source.dart';
import 'dw_data_lifecycle.dart';

/// Source-level guard on state writes in server lib/. Like the other CLI
/// inspectors this reads formatted source, without resolving analyzer types.
final class DwStateColumnsInspector {
  DwStateColumnsInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.stateWrittenDirectly) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.stateWrittenDirectly.severity);

  final Directory? serverPackageDir;
  final bool _enabled;
  final List<String> findings = [];

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (!_enabled || server == null) return 0;
    final lib = Directory(p.join(server.path, 'lib'));
    if (!lib.existsSync()) return 0;
    final files = {
      for (final file in lib.listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          p.relative(file.path, from: server.path): file.readAsStringSync(),
    };
    findings.addAll(writesIn(files));
    for (final finding in findings) {
      print(
        '  ${DwCheckType.stateWrittenDirectly.reportLabel}: $finding; use a guarded transition',
      );
    }
    tally?.add(DwCheckType.stateWrittenDirectly, findings.length);
    return findings.length;
  }

  /// Findings across a server's lib files, keyed by package-relative path.
  static List<String> writesIn(Map<String, String> files) {
    final rows = <String, _StateRow>{};
    final repositories = <String, String>{};
    for (final content in files.values) {
      final source = DwDartSource(content);
      final outline = DwDartOutline(content);
      for (final match in RegExp(
        r'\bclass\s+(\w+)\s+extends\s+DwTableRow\b[^\{]*\{',
      ).allMatches(source.code)) {
        final end = outline.closeOf(match.end - 1);
        final body = source.code.substring(match.end, end);
        final fields = <String, String>{};
        for (final annotation in RegExp(
          r'@(?:\w+\.)?DwStateColumn(?:<[^>]+>)?\s*\(',
        ).allMatches(body)) {
          final after = outline.closeOf(match.end + annotation.end - 1) + 1;
          final field = RegExp(
            r'\bfinal\s+[\w.]+\s+(\w+)\s*;',
          ).firstMatch(source.code.substring(after, end));
          if (field == null) continue;
          final name = field.group(1)!;
          final declarationStart =
              source.code.lastIndexOf(';', match.end + annotation.start) + 1;
          final declarationEnd = after + field.end;
          final declaration = content.substring(
            declarationStart,
            declarationEnd,
          );
          final sqlName =
              RegExp(
                r'''@DwColumnName\(['"]([^'"]+)['"]\)''',
              ).firstMatch(declaration)?.group(1) ??
              name
                  .replaceAllMapped(
                    RegExp(r'(?<=[a-z0-9])(?=[A-Z])'),
                    (_) => '_',
                  )
                  .toLowerCase();
          fields[name] = sqlName;
        }
        if (fields.isEmpty) continue;
        // The table annotation immediately preceding this class.
        final before = content.substring(0, match.start);
        final tables = RegExp(
          r'''@(?:\w+\.)?DwSqlTable\(\s*['"]([^'"]+)['"]''',
        ).allMatches(before);
        if (tables.isNotEmpty)
          rows[match.group(1)!] = _StateRow(tables.last.group(1)!, fields);
      }
      for (final match in RegExp(
        r'get\s+(\w+)\s*=>\s*repository\s*\(\s*(\w+)\s*\.\s*tableDef',
      ).allMatches(source.code)) {
        repositories[match.group(1)!] = match.group(2)!;
      }
    }
    final result = <String>[];
    for (final entry in files.entries) {
      if (entry.key.endsWith('.dw.dart') ||
          entry.key.startsWith('lib/generated/'))
        continue;
      final source = DwDartSource(entry.value, interpolationsAsCode: true);
      final code = source.code;
      final outline = DwDartOutline(entry.value);
      final variables = <String, String>{};
      final aliases = Map.of(repositories);
      for (final match in RegExp(
        r'\b(?:final|var)\s+(\w+)\s*=\s*[\w.]+\.(\w+)\s*;',
      ).allMatches(code)) {
        if (aliases[match.group(2)] case final row?)
          aliases[match.group(1)!] = row;
      }
      for (final row in rows.keys) {
        for (final match in RegExp(
          '\\b${RegExp.escape(row)}\\??\\s+(\\w+)\\b',
        ).allMatches(code)) {
          variables[match.group(1)!] = row;
        }
        for (final match in RegExp(
          '\\b(?:final|var)\\s+(\\w+)\\s*=\\s*(?:await\\s+)?(?:$row\\s*\\(|[\\w.]+\\.accessed<$row>\\s*\\()',
        ).allMatches(code)) {
          variables[match.group(1)!] = row;
        }
      }
      for (final match in RegExp(
        r'\b(?:final|var)\s+(\w+)\s*=\s*(?:await\s+)?(?:[\w.]+\.)?(\w+)\s*\.\s*(?:findById|findFirst|insert|transition)\s*\(',
      ).allMatches(code)) {
        if (aliases[match.group(2)] case final row?)
          variables[match.group(1)!] = row;
      }
      final offsets = <int>{};
      for (final match in RegExp(
        r'\b(\w+)\s*[!?]?\s*\.\s*copyWith\s*\(',
      ).allMatches(code)) {
        final row = rows[variables[match.group(1)]];
        if (row == null) continue;
        final args = code.substring(match.end, outline.closeOf(match.end - 1));
        if (row.fields.keys.any((f) => RegExp('\\b$f\\s*:').hasMatch(args)))
          offsets.add(match.start);
      }
      for (final match in RegExp(
        r'\b(\w+)\s*\.\s*(updateWhereReturning|updateWhere|update|upsertAll|upsert)\s*\(',
      ).allMatches(code)) {
        final row = rows[aliases[match.group(1)]];
        if (row == null) continue;
        final args = code.substring(match.end, outline.closeOf(match.end - 1));
        if (match.group(2)!.startsWith('upsert') ||
            row.fields.keys.any(
              (f) => RegExp(
                '\\.\\s*$f\\s*\\.\\s*set\\s*\\(|\\b$f\\s*:',
              ).hasMatch(args),
            ))
          offsets.add(match.start);
      }
      for (final group in source.stringGroups()) {
        final migration = p.posix.dirname(entry.key) == 'lib/src/migrations';
        if (migration && source.enclosingCall(group.start) == 'backfill')
          continue;
        for (final row in rows.values) {
          final table = RegExp.escape(row.table);
          final sql = group.text;
          // Match the table and its SET clause, including quoted identifiers,
          // schema qualification, aliases and UPDATE ... FROM.
          for (final update in RegExp(
            '\\bUPDATE\\s+(?:"?\\w+"?\\.)?"?$table"?\\b[\\s\\S]*?\\bSET\\s+([^;]+)',
            caseSensitive: false,
          ).allMatches(sql)) {
            if (row.fields.values.any(
              (f) => RegExp(
                '(?:^|,)\\s*"?${RegExp.escape(f)}"?\\s*=',
                caseSensitive: false,
              ).hasMatch(update.group(1)!),
            ))
              offsets.add(group.start);
          }
          if (RegExp(
            '\\bINSERT\\s+INTO\\s+(?:"?\\w+"?\\.)?"?$table"?(?:\\s|\\()',
            caseSensitive: false,
          ).hasMatch(sql))
            offsets.add(group.start);
        }
      }
      final sorted = offsets.toList()..sort();
      for (final offset in sorted) {
        result.add(
          '${entry.key}:${source.lineOf(offset)} stateWrittenDirectly',
        );
      }
    }
    return result;
  }
}

final class _StateRow {
  const _StateRow(this.table, this.fields);
  final String table;
  final Map<String, String> fields;
}
