import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';

/// How a project's data comes to be and changes: seeds, migrations, settings
/// and patches, each with the one pattern the framework has for it
/// (dartway/dartway#388).
///
/// - [DwCheckType.migrationChangesData]: an `INSERT`, `UPDATE` or `DELETE` in
///   a migration outside `m.backfill(…)`;
/// - [DwCheckType.workAfterServerStart]: `bin/server.dart` doing work after
///   `server.start()`;
/// - [DwCheckType.settingsKeyValueTable]: a row class that is a key/value
///   store — a unique `String key` beside a `String value`;
/// - [DwCheckType.fieldPatchMatched]: `DwSetField`, `DwClearField` or
///   `DwKeepField` named in the project's code.
///
/// All four read the source with comments removed and strings blanked, so a
/// name in a comment or a string is not code — except the migration check,
/// which reads the strings, since SQL is where the statement is.
class DwDataLifecycleInspector {
  DwDataLifecycleInspector({
    required this.serverPackageDir,
    required this.sharedPackageDir,
    required this.flutterPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled = {
         for (final type in checks)
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  /// The checks this inspector runs.
  static const checks = [
    DwCheckType.migrationChangesData,
    DwCheckType.workAfterServerStart,
    DwCheckType.settingsKeyValueTable,
    DwCheckType.fieldPatchMatched,
  ];

  final Directory? serverPackageDir;
  final Directory? sharedPackageDir;
  final Directory? flutterPackageDir;
  final Set<DwCheckType> _enabled;
  final _findings = <(DwCheckType, String)>[];

  /// What was found, as `(check, finding)`.
  List<(DwCheckType, String)> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (server != null && server.existsSync()) {
      final root = server.parent.path;
      if (_enabled.contains(DwCheckType.migrationChangesData)) {
        final folder = Directory(
          p.join(server.path, 'lib', 'src', 'migrations'),
        );
        final migrations = {
          for (final file in _dartFiles(folder, recursive: false))
            if (RegExp(r'^m(\d.*)\.dart$').firstMatch(p.basename(file.path))
                case final match?)
              match.group(1)!: file,
        };
        final (after, problem) = dataChecksAfter(Directory(root));
        if (problem != null) {
          _add(DwCheckType.migrationChangesData, problem);
        } else if (after != null && !migrations.containsKey(after)) {
          _add(
            DwCheckType.migrationChangesData,
            '`$configKey: $after` in deploy/config.yaml names no migration '
            'in ${p.relative(folder.path, from: root)}',
          );
        }
        final judged = migrations.keys.toList()..sort();
        for (final id in judged) {
          // Migrations up to the cutoff were applied before the project
          // adopted this rule: an applied migration is never edited.
          if (after != null && id.compareTo(after) <= 0) continue;
          final file = migrations[id]!;
          for (final (line, statement) in dataChangesIn(
            file.readAsStringSync(),
          )) {
            _add(
              DwCheckType.migrationChangesData,
              statement.contains(' dw_')
                  ? '`$statement` — ${p.relative(file.path, from: root)}:$line; '
                        'the framework\'s tables are written by the framework '
                        '— a settings table is carried with `m.carrySettings`'
                  : '`$statement` — ${p.relative(file.path, from: root)}:$line; '
                        'rows the schema change strands go through '
                        '`m.backfill(…)`, content is a `DwSeedRows` step',
            );
          }
        }
      }
      if (_enabled.contains(DwCheckType.workAfterServerStart)) {
        final entry = File(p.join(server.path, 'bin', 'server.dart'));
        if (entry.existsSync()) {
          for (final (line, what) in workAfterStartIn(
            entry.readAsStringSync(),
          )) {
            _add(
              DwCheckType.workAfterServerStart,
              '`$what` — ${p.relative(entry.path, from: root)}:$line; '
              'start-up work is a `DwStartupStep` (`startup:`), seeds a '
              '`DwSeedRows` — both run before the port opens',
            );
          }
        }
      }
      if (_enabled.contains(DwCheckType.settingsKeyValueTable)) {
        for (final file in _dartFiles(Directory(p.join(server.path, 'lib')))) {
          for (final (line, table) in keyValueTablesIn(
            file.readAsStringSync(),
          )) {
            _add(
              DwCheckType.settingsKeyValueTable,
              '`$table` — ${p.relative(file.path, from: root)}:$line; '
              'settings are a data object with defaults, through '
              '`ctx.settings`',
            );
          }
        }
      }
    }
    if (_enabled.contains(DwCheckType.fieldPatchMatched)) {
      for (final package in [
        serverPackageDir,
        sharedPackageDir,
        flutterPackageDir,
      ]) {
        if (package == null || !package.existsSync()) continue;
        for (final folder in ['lib', 'bin', 'test']) {
          for (final file in _dartFiles(
            Directory(p.join(package.path, folder)),
          )) {
            for (final (line, name) in patchMatchesIn(
              file.readAsStringSync(),
            )) {
              _add(
                DwCheckType.fieldPatchMatched,
                '`$name` — ${p.relative(file.path, from: package.parent.path)}'
                ':$line; read it with `apply`, `newValue`, `map`, `isSet`, '
                '`isCleared`, `trimmedOrCleared`',
              );
            }
          }
        }
      }
    }

    if (_findings.isEmpty) return 0;
    print('\n🗄️ Data lifecycle:\n');
    for (final (type, finding) in _findings) {
      print('  ${type.reportLabel}: $finding');
    }
    var errors = 0;
    for (final type in checks) {
      final count = _findings.where((finding) => finding.$1 == type).length;
      tally?.add(type, count);
      if (type.severity == DwCheckSeverity.error) errors += count;
    }
    return errors;
  }

  void _add(DwCheckType type, String finding) => _findings.add((type, finding));

  /// The key in `deploy/config.yaml` naming the last migration that is not
  /// judged by [DwCheckType.migrationChangesData].
  static const configKey = 'migrations > dataChecksAfter';

  /// The migration id `deploy/config.yaml` > `migrations` >
  /// `dataChecksAfter` names, or `null` when it names none; and a problem when
  /// the key is there but is not a migration id.
  ///
  /// A project that adopts the rule has migrations that already ran
  /// everywhere, and an applied migration is never edited. It names its
  /// latest migration here once, and only the migrations after it are judged;
  /// a project that never set it — every new one — has all of them judged.
  static (String?, String?) dataChecksAfter(Directory projectRoot) {
    final file = File(p.join(projectRoot.path, 'deploy', 'config.yaml'));
    if (!file.existsSync()) return (null, null);
    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException {
      return (null, null);
    }
    if (document is! YamlMap) return (null, null);
    final migrations = document['migrations'];
    if (migrations == null) return (null, null);
    final value = migrations is YamlMap ? migrations['dataChecksAfter'] : null;
    if (value is String && RegExp(r'^\d{8}_\d{6}_\w+$').hasMatch(value)) {
      return (value, null);
    }
    return (
      null,
      'deploy/config.yaml: `$configKey` must be a migration id '
          '(`20260930_120000_name`), got `${value ?? migrations}`',
    );
  }

  /// Every `.dart` file under [folder] that is not generated, in path order.
  static List<File> _dartFiles(Directory folder, {bool recursive = true}) {
    if (!folder.existsSync()) return const [];
    return folder
        .listSync(recursive: recursive)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.dw.dart') &&
              !file.path.endsWith('.g.dart') &&
              !p.split(file.path).contains('generated') &&
              !p.split(file.path).contains('gen') &&
              !p.split(file.path).contains('.dart_tool'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  static final _dataChange = RegExp(
    r'\b(insert\s+into|update\s+(?:only\s+)?[\w."]+(?:\s+(?:as\s+)?\w+)?\s+set|delete\s+from)\b',
    caseSensitive: false,
  );

  /// Bodies of functions and procedures are definitions, not statements the
  /// migration runs.
  /// A function or procedure being defined: its dollar-quoted body is a
  /// definition, not statements the migration runs.
  static final _routine = RegExp(
    r'\bcreate\s+(?:or\s+replace\s+)?(?:function|procedure)\b',
    caseSensitive: false,
  );

  static final _dollarQuoted = RegExp(r'\$(\w*)\$[\s\S]*?\$\1\$');

  static final _sqlLineComment = RegExp(r'--[^\n]*');

  /// [sql] as the statements it runs: `--` comments dropped, and a routine's
  /// body when it is defining one.
  static String _statements(String sql) {
    var text = sql.replaceAll(_sqlLineComment, ' ');
    if (_routine.hasMatch(text)) text = text.replaceAll(_dollarQuoted, ' ');
    // A rule's action is a definition too: what it does instead, later.
    if (_rule.firstMatch(text) case final rule?) {
      final action = RegExp(
        r'\bdo\b',
        caseSensitive: false,
      ).allMatches(text, rule.end).firstOrNull;
      if (action != null) text = text.substring(0, action.start);
    }
    return text;
  }

  static final _rule = RegExp(
    r'\bcreate\s+(?:or\s+replace\s+)?rule\b',
    caseSensitive: false,
  );

  /// A write into one of the framework's own tables.
  static final _frameworkWrite = RegExp(
    r'\b(insert\s+into|update(?:\s+only)?|delete\s+from)\s+"?(dw_\w+)',
    caseSensitive: false,
  );

  /// `INSERT`, `UPDATE` and `DELETE` statements in [content]'s strings that
  /// are not an argument of `backfill(…)`, as `(line, statement keyword)`.
  ///
  /// Adjacent literals are read as the one string they are, so a statement
  /// split across lines is found; a literal held in a variable is judged
  /// where it is written, not where it is used.
  static List<(int, String)> dataChangesIn(String content) {
    final source = DwDartSource(content, interpolationsAsCode: true);
    final found = <(int, String)>[];
    for (final group in source.stringGroups()) {
      final statements = _statements(group.text);
      final match = _dataChange.firstMatch(statements);
      if (match == null) continue;
      // The framework's tables are the framework's, `backfill` or not.
      if (_frameworkWrite.firstMatch(statements) case final write?) {
        found.add((
          source.lineOf(group.start),
          '${write.group(1)!.split(RegExp(r'\s+')).first.toUpperCase()} '
              '${write.group(2)}',
        ));
        continue;
      }
      if (source.enclosingCall(group.start) == 'backfill') continue;
      found.add((
        source.lineOf(group.start),
        match.group(1)!.split(RegExp(r'\s+')).first.toUpperCase(),
      ));
    }
    return found;
  }

  /// A variable holding the app's server: `final server =
  /// AcmeServer.build(…)` or `= DwAppServer(…)`.
  static final _serverVariable = RegExp(
    r'\b(?:final|var)\s+(?:\w+\s+)?(\w+)\s*=\s*(?:await\s+)?'
    r'(?:DwAppServer\s*\(|\w*Server\s*\.\s*build\s*\()',
  );

  /// Where the server's own `.start()` ends: the start of the variable a
  /// server was assigned to, or — with none found — the first awaited
  /// `x.start()`. Never a cascade (`Stopwatch()..start()`).
  static int? _serverStartEnd(String code) {
    for (final variable in _serverVariable.allMatches(code)) {
      final name = RegExp.escape(variable.group(1)!);
      final start = RegExp(
        '(?<![.\\w])$name\\s*\\.\\s*start\\s*\\([^)]*\\)',
      ).allMatches(code, variable.end).firstOrNull;
      if (start != null) return start.end;
    }
    return RegExp(
      r'\bawait\s+\w+\s*\.\s*start\s*\(\s*\)',
    ).firstMatch(code)?.end;
  }

  static final _work = RegExp(
    r'\bawait\b|\.\s*db\b|\.\s*accounts\b|\brunInContext\b',
  );

  /// Shutdown, not work: awaiting the server's `stop()`/`close()`, or a
  /// signal to stop on.
  static final _shutdown = RegExp(
    r'^await\s+(?:[\w.]+\.\s*(?:stop|close)\s*\(|'
    r'ProcessSignal\s*\.\s*\w+\s*\.\s*watch\s*\(\s*\))',
  );

  /// What [content] does after the server's `.start()` in the function that
  /// calls it, as `(line, what)`: an `await`, or a reach into the started
  /// server's database or accounts. Awaiting `stop()`/`close()` or a
  /// `ProcessSignal` is shutdown, not work, and passes.
  static List<(int, String)> workAfterStartIn(String content) {
    final source = DwDartSource(content, interpolationsAsCode: true);
    final code = source.code;
    final startEnd = _serverStartEnd(code);
    if (startEnd == null) return const [];
    var depth = 0;
    var end = code.length;
    for (var i = startEnd; i < code.length; i++) {
      final char = code[i];
      if (char == '{') depth++;
      if (char == '}') {
        if (depth == 0) {
          end = i;
          break;
        }
        depth--;
      }
    }
    final found = <(int, String)>[];
    final lines = <int>{};
    for (final match in _work.allMatches(code.substring(startEnd, end))) {
      final at = startEnd + match.start;
      if (_shutdown.hasMatch(code.substring(at))) continue;
      final line = source.lineOf(at);
      if (!lines.add(line)) continue;
      // The whole line as written, strings included.
      final text = content.split('\n')[line - 1].trim();
      found.add((
        line,
        text.length > 60 ? '${text.substring(0, 57)}...' : text,
      ));
    }
    return found;
  }

  static final _table = RegExp(r'''@DwSqlTable\(\s*['"]([^'"]+)['"]''');
  static final _uniqueKey = RegExp(
    r'@DwUniqueColumn\s*\([^)]*\)\s*(?:@\w+(?:\([^)]*\))?\s*)*final\s+String\s+key\s*;',
  );
  static final _value = RegExp(r'\bfinal\s+String\??\s+value\s*;');

  /// Row classes in [content] that are a key/value store — a unique
  /// `String key` beside a `String value` — as `(line, table)`.
  static List<(int, String)> keyValueTablesIn(String content) {
    final source = DwDartSource(content, interpolationsAsCode: true);
    // Table names are strings, which the blanked code no longer holds: the
    // annotations are found in the source, and judged in the code.
    final code = source.code;
    final found = <(int, String)>[];
    for (final table in _table.allMatches(content)) {
      // The annotated class's own body, from its `{` to the matching `}`.
      final open = code.indexOf('{', table.end);
      if (open < 0) continue;
      var depth = 0;
      var close = code.length;
      for (var i = open; i < code.length; i++) {
        if (code[i] == '{') depth++;
        if (code[i] == '}' && --depth == 0) {
          close = i;
          break;
        }
      }
      final body = code.substring(table.start, close);
      if (_uniqueKey.hasMatch(body) && _value.hasMatch(body)) {
        found.add((source.lineOf(table.start), table.group(1)!));
      }
    }
    return found;
  }

  static final _patchVariant = RegExp(
    r'\b(DwSetField|DwClearField|DwKeepField)\b',
  );

  /// `DwSetField`, `DwClearField` and `DwKeepField` in [content]'s code, as
  /// `(line, name)`.
  static List<(int, String)> patchMatchesIn(String content) {
    final source = DwDartSource(content, interpolationsAsCode: true);
    return [
      for (final match in _patchVariant.allMatches(source.code))
        (source.lineOf(match.start), match.group(1)!),
    ];
  }
}

/// A string literal run: adjacent literals, read as the one string they are.
final class DwStringGroup {
  const DwStringGroup(this.start, this.text);

  /// Offset where the first literal starts: its `r` when raw, else its quote.
  final int start;

  /// The literals' contents, joined.
  final String text;
}

/// How the data checks read a source's strings: as the SQL they hold.
extension on DwDartSource {
  /// Runs of literals separated by nothing but whitespace, each read as the
  /// one string it is.
  List<DwStringGroup> stringGroups() {
    final groups = <DwStringGroup>[];
    int? start;
    var end = 0;
    final text = StringBuffer();
    for (final literal in literals) {
      final value = _valueOf(literal);
      if (start != null && code.substring(end, literal.start).trim().isEmpty) {
        text.write(value);
      } else {
        if (start != null) groups.add(DwStringGroup(start, text.toString()));
        start = literal.start;
        text
          ..clear()
          ..write(value);
      }
      end = literal.end;
    }
    if (start != null) groups.add(DwStringGroup(start, text.toString()));
    return groups;
  }

  /// The text [literal] holds: an escaped line break is one, and an
  /// interpolation — `${table}` or `$table` — is read as a name, so
  /// `UPDATE ${table} SET` is still a statement.
  String _valueOf(DwStringLiteral literal) {
    final value = StringBuffer();
    final interpolations = literal.interpolations.iterator;
    var next = interpolations.moveNext() ? interpolations.current : null;
    var i = literal.contentStart;
    while (i < literal.contentEnd) {
      if (next != null && next.$1 == i) {
        value.write('interpolated_name');
        i = next.$2;
        next = interpolations.moveNext() ? interpolations.current : null;
        continue;
      }
      if (!literal.raw && content[i] == r'\' && i + 1 < literal.contentEnd) {
        value.write(switch (content[i + 1]) {
          'n' => '\n',
          't' => '\t',
          final other => other,
        });
        i += 2;
        continue;
      }
      value.write(content[i]);
      i++;
    }
    return value.toString();
  }

  /// The name of the call whose argument list holds [offset] — `backfill`
  /// for `m.backfill('…')` — or `null` when it is in none.
  String? enclosingCall(int offset) {
    var depth = 0;
    for (var i = offset - 1; i >= 0; i--) {
      final char = code[i];
      if (char == ')' || char == ']' || char == '}') depth++;
      if (char == '(' || char == '[' || char == '{') {
        if (depth == 0) {
          if (char != '(') return null;
          final name = RegExp(
            r'(\w+)\s*(?:<[^()]*>)?\s*$',
          ).firstMatch(code.substring(0, i));
          return name?.group(1);
        }
        depth--;
      }
    }
    return null;
  }
}
