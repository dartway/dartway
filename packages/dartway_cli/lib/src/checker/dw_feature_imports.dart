import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';
import 'dw_layout.dart';
import 'dw_server_features.dart';

/// The kinds of a server feature's files another feature may import: its
/// rows (to read and join its tables — never to write them), its access rules
/// (whose row it is, who is a member), its data objects (a row shown the one
/// way the feature shows it), its publications (a change announced the one
/// way the feature announces it) and its changes (a row written the one way
/// that keeps the feature's invariants). A part of a kind counts as the kind
/// (`chat_messages_rows.dart`).
///
/// Never its `_feature`, `_handlers`, `_jobs`, `_routes` or anything in its
/// `logic/`: those run the feature, and another feature running them is two
/// features doing one's work.
const dwFeatureSurfaceKinds = [
  'rows',
  'access',
  'objects',
  'publications',
  'changes',
];

/// The repository calls that write a table.
const dwTableWriteMethods = [
  'insert',
  'tryInsert',
  'insertAll',
  'update',
  'updateWhere',
  'updateWhereReturning',
  'upsert',
  'upsertAll',
  'delete',
  'deleteWhere',
];

/// How the server's features depend on one another
/// ([DwCheckType.featureImportCycle], [DwCheckType.coreImportsFeature],
/// [DwCheckType.featureImportOutsideSurface], [DwCheckType.foreignRowWrite];
/// dartway/dartway#382).
///
/// Read from the `import`/`export`/`part` directives of every file under
/// `lib/src/` — `package:` or relative, conditional ones included — and from
/// the writes through `db.<table>`, with no analyzer: a file of a feature is
/// `lib/src/<feature>/…`, a file of `core/` is `lib/src/core/…`. Four rules:
///
/// - **`core/` imports no feature**, and no file under `lib/src/` imports the
///   package's library, which imports every feature.
/// - **The features form a graph without cycles.** Every import counts,
///   within the surface or not: two features that import each other are one
///   feature in two folders, and neither can be read, tested or moved alone.
/// - **A feature imports another only through its surface**,
///   [dwFeatureSurfaceKinds].
/// - **A row is written only by the feature that declares it**: a
///   `<handle>.<table>.insert|update|delete…` of another feature's table —
///   through `ctx.db`, a transaction's handle or any other — the
///   generated schema names each table's row class, and the row class's file
///   names its feature — is a finding; the owner's `_changes` is the way in.
///
/// `lib/<package>_server.dart` assembles the server from every feature and is
/// not judged; nor are `migrations/`, `bin/` and `test/`. A repository held
/// in a variable and written through it is not seen.
class DwFeatureImportInspector {
  DwFeatureImportInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabledTypes = {
         for (final type in _types)
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  static const _types = [
    DwCheckType.featureImportCycle,
    DwCheckType.coreImportsFeature,
    DwCheckType.featureImportOutsideSurface,
    DwCheckType.foreignRowWrite,
  ];

  final Directory? serverPackageDir;
  final Set<DwCheckType> _enabledTypes;
  final _cycleFindings = <String>[];
  final _coreFindings = <String>[];
  final _surfaceFindings = <String>[];
  final _writeFindings = <String>[];

  /// [DwCheckType.featureImportCycle]'s findings, one per knot of features.
  List<String> get cycleFindings => List.unmodifiable(_cycleFindings);

  /// [DwCheckType.coreImportsFeature]'s findings, one per directive.
  List<String> get coreFindings => List.unmodifiable(_coreFindings);

  /// [DwCheckType.featureImportOutsideSurface]'s findings, one per directive.
  List<String> get surfaceFindings => List.unmodifiable(_surfaceFindings);

  /// [DwCheckType.foreignRowWrite]'s findings, one per write call.
  List<String> get writeFindings => List.unmodifiable(_writeFindings);

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (server == null || _enabledTypes.isEmpty) return 0;
    final lib = Directory(p.join(server.path, 'lib'));
    final src = Directory(p.join(lib.path, 'src'));
    if (!src.existsSync()) return 0;
    final package = _packageName(server);

    final files = <String, String>{
      for (final file
          in src
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (file) =>
                    file.path.endsWith('.dart') &&
                    !file.path.endsWith('.dw.dart'),
              ))
        p.posix.joinAll(p.split(p.relative(file.path, from: src.path))): file
            .readAsStringSync(),
    };
    final paths = files.keys.toList()..sort();

    // feature → the features it imports, each with the first directive seen.
    final edges = <String, Map<String, String>>{};
    for (final from in paths) {
      final fromArea = _area(from);
      if (fromArea == null || fromArea == 'migrations') continue;
      for (final (line, uri) in importsIn(files[from]!)) {
        final target = _underLib(uri, 'src/$from', package);
        if (target == null) continue;
        final where = '$from:$line';
        if (!target.contains('/')) {
          (fromArea == 'core' ? _coreFindings : _surfaceFindings).add(
            '$where imports $target — the package\'s library, which imports '
            'every feature: import what is needed from the file that '
            'declares it',
          );
          continue;
        }
        if (!target.startsWith('src/')) continue;
        final to = target.substring('src/'.length);
        final toArea = _area(to);
        if (toArea == null ||
            toArea == 'core' ||
            toArea == 'migrations' ||
            toArea == fromArea) {
          continue;
        }
        if (fromArea == 'core') {
          _coreFindings.add(
            '$where imports $to — core/ imports no feature: what needs '
            '$toArea moves into it (a rule, or who the caller is, into '
            '${toArea}_access.dart), or into a feature above the ones it '
            'needs',
          );
          continue;
        }
        edges.putIfAbsent(fromArea, () => {}).putIfAbsent(toArea, () => where);
        if (surfaceKindOf(toArea, to) == null) {
          _surfaceFindings.add(
            '$where imports $to — outside $toArea\'s surface '
            '(${dwFeatureSurfaceKinds.map((k) => '${toArea}_$k').join(', ')}): '
            'a rule moves to ${toArea}_access.dart, a write to '
            '${toArea}_changes.dart, what only $fromArea uses moves to '
            '$fromArea, what both need to a feature both import',
          );
        }
      }
    }
    for (final knot in knotsOf(edges)) {
      final cycle = shortestCycle(knot, edges);
      final steps = [
        for (var i = 0; i < cycle.length; i++)
          '${cycle[i]} → ${cycle[(i + 1) % cycle.length]} '
              '(${edges[cycle[i]]![cycle[(i + 1) % cycle.length]]})',
      ];
      final rest = knot.where((f) => !cycle.contains(f)).toList();
      _cycleFindings.add(
        '${[...cycle, cycle.first].join(' → ')}: ${steps.join('; ')}'
        '${rest.isEmpty ? '' : ' — and ${rest.join(', ')} in the same knot'}'
        '; break it by moving the shared rule to the owning feature\'s '
        '_access, or a row to the feature that owns its invariants',
      );
    }
    _checkWrites(lib, files, paths);

    final findings = [
      for (final (type, list) in [
        (DwCheckType.featureImportCycle, _cycleFindings),
        (DwCheckType.coreImportsFeature, _coreFindings),
        (DwCheckType.featureImportOutsideSurface, _surfaceFindings),
        (DwCheckType.foreignRowWrite, _writeFindings),
      ])
        if (_enabledTypes.contains(type))
          for (final finding in list) (type, finding),
    ];
    if (findings.isEmpty) return 0;
    print('\n🕸️ Feature imports and writes:\n');
    for (final (type, finding) in findings) {
      print('  ${type.reportLabel}: $finding');
    }
    var errors = 0;
    for (final type in _types) {
      final count = findings.where((f) => f.$1 == type).length;
      tally?.add(type, count);
      if (type.severity == DwCheckSeverity.error) errors += count;
    }
    return errors;
  }

  /// A write through `db.<table>` in a file of `core/` or of a feature that
  /// does not declare the table's row class.
  void _checkWrites(
    Directory lib,
    Map<String, String> files,
    List<String> paths,
  ) {
    final schema = File(p.join(lib.path, 'generated', 'dw_schema.dart'));
    if (!schema.existsSync()) return;
    final rowOf = {
      for (final match in _schemaGetter.allMatches(
        DwDartSource(schema.readAsStringSync()).code,
      ))
        match.group(1)!: match.group(2)!,
    };
    final featureOf = <String, String>{};
    for (final path in paths) {
      final area = _area(path);
      if (area == null || area == 'core' || area == 'migrations') continue;
      for (final match in _rowClass.allMatches(
        DwDartSource(files[path]!).code,
      )) {
        featureOf[match.group(1)!] = area;
      }
    }
    for (final path in paths) {
      final area = _area(path);
      if (area == null || area == 'migrations') continue;
      final content = files[path]!;
      final code = DwDartSource(content).code;
      for (final match in _tableWrite.allMatches(code)) {
        final row = rowOf[match.group(1)];
        final owner = row == null ? null : featureOf[row];
        if (owner == null || owner == area) continue;
        final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
        _writeFindings.add(
          '$path:$line writes ${match.group(1)} (${match.group(2)}) — '
          '$row is $owner\'s: call a function of ${owner}_changes.dart, '
          'the one place its invariants are kept',
        );
      }
    }
  }

  static final _schemaGetter = RegExp(
    r'get\s+(\w+)\s*=>\s*repository\s*\(\s*(\w+)\s*\.\s*tableDef',
  );

  static final _rowClass = RegExp(r'class\s+(\w+)\s+extends\s+DwTableRow\b');

  /// `<receiver>.<getter>.<write>(` whatever the receiver — `ctx.db`, a
  /// transaction's handle (`tx`), a helper's `db` — and only when the getter
  /// is one of the generated schema's.
  static final _tableWrite = RegExp(
    '(?<=\\.)\\s*(\\w+)\\s*\\.\\s*(${dwTableWriteMethods.join('|')})'
    '\\s*[(<]',
  );

  /// The kind of [path] (under `lib/src/`) when it is in [feature]'s surface,
  /// or null: a file straight in the feature's folder named
  /// `<feature>[_<part>]_<kind>.dart`, the kind one of
  /// [dwFeatureSurfaceKinds].
  static String? surfaceKindOf(String feature, String path) {
    final segments = p.posix.split(path);
    if (segments.length != 2) return null;
    final kind = dwServerFeatureFileKind(feature, segments.last);
    return dwFeatureSurfaceKinds.contains(kind) ? kind : null;
  }

  /// Every `import`/`export`/`part` URI in [content] with its line, the
  /// alternatives of a conditional import included; `part of` is not one.
  /// Found in the text with comments and strings blanked, so a directive
  /// quoted in a string is not one.
  static List<(int, String)> importsIn(String content) {
    final source = DwDartSource(content);
    final code = source.code;
    final result = <(int, String)>[];
    for (final match in _directive.allMatches(code)) {
      final end = code.indexOf(';', match.end);
      if (end < 0) continue;
      for (final literal in source.literals) {
        if (literal.start < match.end || literal.end > end) continue;
        result.add((source.lineOf(literal.contentStart), literal.text));
      }
    }
    return result;
  }

  /// The knots of [edges]: its strongly connected sets of more than one
  /// feature, each sorted, in order of their first feature.
  static List<List<String>> knotsOf(Map<String, Map<String, String>> edges) {
    final nodes = {
      ...edges.keys,
      for (final targets in edges.values) ...targets.keys,
    }.toList()..sort();
    var counter = 0;
    final index = <String, int>{};
    final low = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final knots = <List<String>>[];

    void connect(String node) {
      index[node] = low[node] = counter++;
      stack.add(node);
      onStack.add(node);
      for (final next in (edges[node]?.keys.toList() ?? <String>[])..sort()) {
        if (!index.containsKey(next)) {
          connect(next);
          low[node] = low[node]! < low[next]! ? low[node]! : low[next]!;
        } else if (onStack.contains(next)) {
          low[node] = low[node]! < index[next]! ? low[node]! : index[next]!;
        }
      }
      if (low[node] == index[node]) {
        final knot = <String>[];
        String member;
        do {
          member = stack.removeLast();
          onStack.remove(member);
          knot.add(member);
        } while (member != node);
        if (knot.length > 1) knots.add(knot..sort());
      }
    }

    for (final node in nodes) {
      if (!index.containsKey(node)) connect(node);
    }
    return knots..sort((a, b) => a.first.compareTo(b.first));
  }

  /// A shortest cycle of [knot], by edges inside it: the shortest through
  /// each of its features, the first found among equals, starting at the
  /// feature it was found from.
  static List<String> shortestCycle(
    List<String> knot,
    Map<String, Map<String, String>> edges,
  ) {
    List<String>? best;
    for (final start in knot) {
      final cycle = _shortestCycleThrough(start, knot.toSet(), edges);
      if (cycle != null && (best == null || cycle.length < best.length)) {
        best = cycle;
      }
    }
    return best ?? knot;
  }

  static List<String>? _shortestCycleThrough(
    String start,
    Set<String> inside,
    Map<String, Map<String, String>> edges,
  ) {
    final previous = <String, String>{};
    final queue = [start];
    for (var i = 0; i < queue.length; i++) {
      final node = queue[i];
      for (final next in (edges[node]?.keys.toList() ?? <String>[])..sort()) {
        if (!inside.contains(next)) continue;
        if (next == start) {
          final path = [node];
          while (path.last != start) {
            path.add(previous[path.last]!);
          }
          return path.reversed.toList();
        }
        if (previous.containsKey(next)) continue;
        previous[next] = node;
        queue.add(next);
      }
    }
    return null;
  }

  static final _directive = RegExp(
    r'^[ \t]*(?:import|export|part)\b(?!\s+of\b)',
    multiLine: true,
  );

  /// The top folder of [path] under `lib/src/` when it names a feature,
  /// `core` or `migrations`; null for a file at the top of `src/` or a
  /// folder the layout refuses, which are [DwLayoutInspector]'s findings.
  static String? _area(String path) {
    final segments = p.posix.split(path);
    if (segments.length < 2) return null;
    final area = segments.first;
    if (dwServerForbiddenFolders.contains(area) ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(area)) {
      return null;
    }
    return area;
  }

  /// [uri], written in the file at [from] (under `lib/`), as a path under
  /// `lib/`, or null when it leads out of the package.
  static String? _underLib(String uri, String from, String package) {
    final prefix = 'package:$package/';
    if (uri.startsWith(prefix)) {
      return p.posix.normalize(uri.substring(prefix.length));
    }
    if (uri.contains(':')) return null;
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(from), uri),
    );
    return resolved.startsWith('../') || resolved == '..' ? null : resolved;
  }

  static String _packageName(Directory server) {
    final pubspec = File(p.join(server.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final name = (loadYaml(pubspec.readAsStringSync()) as Map?)?['name'];
      if (name is String) return name;
    }
    return p.basename(server.path);
  }
}
