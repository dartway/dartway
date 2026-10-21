import 'dw_dart_source.dart';
import 'dw_dart_outline.dart';
import 'dw_data_lifecycle.dart';

/// Required additions to an existing table break the previous release's
/// inserts while both server versions run. This is a narrow source check,
/// not a proof of general expand/contract compatibility.
List<(int, String)> dwUnsafeMigrationColumns(String content) {
  final source = DwDartSource(content);
  // Down migrations do not run during the forward deployment switch.
  final down = <(int, int)>[];
  for (final method in RegExp(
    r'\bdown\s*\([^)]*\)\s*(?:async\s*)?\{',
  ).allMatches(source.code)) {
    var depth = 1;
    var end = method.end;
    while (end < source.code.length && depth > 0) {
      if (source.code[end] == '{') depth++;
      if (source.code[end] == '}') depth--;
      end++;
    }
    down.add((method.start, end));
  }
  final groups = source.stringGroups().where(
    (g) => !down.any((range) => g.start >= range.$1 && g.start < range.$2),
  );
  String sql(String text) =>
      text.replaceAll(RegExp(r"'(''|[^'])*'|--[^\n]*|/\*[\s\S]*?\*/"), ' ');
  const identifier = r'(?:"[^"]+"|\w+)(?:\s*\.\s*(?:"[^"]+"|\w+))?';
  String key(String name) =>
      name.replaceAll(RegExp(r'["\s]'), '').toLowerCase();
  final create = RegExp(
    '\\bCREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?($identifier)',
    caseSensitive: false,
  );
  final created = {
    for (final group in groups)
      for (final match in create.allMatches(sql(group.text))) key(match[1]!),
  };
  final outline = DwDartOutline(content);
  bool forward(int offset) => !down.any((r) => offset >= r.$1 && offset < r.$2);
  for (final call in RegExp(r'\bcreateTable\s*\(').allMatches(source.code)) {
    if (!forward(call.start)) continue;
    final end = outline.closeOf(call.end - 1);
    final name = groups
        .where((g) => g.start >= call.end && g.start < end)
        .firstOrNull;
    if (name != null) created.add(key(name.text));
  }
  final builderFindings = <(int, String)>[];
  for (final call in RegExp(r'\baddColumn\s*\(').allMatches(source.code)) {
    if (!forward(call.start)) continue;
    final end = outline.closeOf(call.end - 1);
    final column = RegExp(
      r'\bDwColumnSchema\s*\(',
    ).allMatches(source.code, call.end).where((m) => m.start < end).firstOrNull;
    if (column == null) continue;
    final columnEnd = outline.closeOf(column.end - 1);
    final fields = source.code.substring(column.end, columnEnd);
    if (RegExp(r'\bnullable\s*:\s*true\b').hasMatch(fields)) continue;
    final defaultValue = RegExp(r'\bdefaultSql\s*:\s*(\S+)').firstMatch(fields);
    if (defaultValue != null && !defaultValue[1]!.startsWith('null')) continue;
    final tableName = groups
        .where((g) => g.start >= call.end && g.start < column.start)
        .firstOrNull;
    final columnName = groups
        .where((g) => g.start >= column.end && g.start < columnEnd)
        .firstOrNull;
    if (tableName == null ||
        columnName == null ||
        created.contains(key(tableName.text)))
      continue;
    builderFindings.add((
      source.lineOf(call.start),
      '${tableName.text}.${columnName.text}',
    ));
  }
  final alter = RegExp(
    '\\bALTER\\s+TABLE\\s+(?:IF\\s+EXISTS\\s+)?(?:ONLY\\s+)?($identifier)\\s+([^;]+)',
    caseSensitive: false,
  );
  final add = RegExp(
    r'^\s*ADD\s+(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?("[^"]+"|\w+)\s+([\s\S]+)',
    caseSensitive: false,
  );
  final required = RegExp(r'\bNOT\s+NULL\b', caseSensitive: false);
  final supplied = RegExp(
    r'\bDEFAULT\b|\bGENERATED\s+(?:ALWAYS|BY\s+DEFAULT)\b',
    caseSensitive: false,
  );
  return [
    ...builderFindings,
    for (final group in groups)
      for (final table in alter.allMatches(sql(group.text)))
        if (!created.contains(key(table[1]!)))
          for (final action in _actions(table[2]!))
            if (add.firstMatch(action) case final column?)
              if (required.hasMatch(column[2]!) &&
                  !supplied.hasMatch(column[2]!))
                (source.lineOf(group.start), '${table[1]}.${column[1]}'),
  ];
}

/// Commas in a type, expression or function do not start another ALTER action.
Iterable<String> _actions(String text) sync* {
  var start = 0;
  var depth = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '"') quoted = !quoted;
    if (quoted) continue;
    if (text[i] == '(') depth++;
    if (text[i] == ')') depth--;
    if (text[i] == ',' && depth == 0) {
      yield text.substring(start, i);
      start = i + 1;
    }
  }
  yield text.substring(start);
}
