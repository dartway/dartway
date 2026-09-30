import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_outline.dart';
import 'dw_layout.dart';

/// What a file of a server feature may be: `<feature>_<kind>.dart`, or
/// `<feature>_<part>_<kind>.dart` when a big feature splits a kind in parts.
/// The set is closed; everything else a feature needs lives in its `logic/`.
const dwServerFeatureFileKinds = [
  'feature',
  'rows',
  'handlers',
  'objects',
  'publications',
  'jobs',
  'access',
  'routes',
  'changes',
];

/// The one subfolder a server feature may have.
const dwServerFeatureLogicFolder = 'logic';

/// The kind of a feature's file named [fileName], or null when the name is not
/// `<feature>_<kind>.dart` / `<feature>_<part>_<kind>.dart`. A `feature` file
/// has no part: a feature declares itself once. A part is never a kind's name
/// (`orders_jobs_handlers.dart` says two kinds at once).
String? dwServerFeatureFileKind(String feature, String fileName) {
  final match = RegExp(
    '^${RegExp.escape(feature)}_(?:([a-z][a-z0-9_]*)_)?'
    '(${dwServerFeatureFileKinds.join('|')})\\.dart\$',
  ).firstMatch(fileName);
  if (match == null) return null;
  final part = match.group(1);
  if (match.group(2) == 'feature' && part != null) return null;
  if (part != null && part.split('_').any(dwServerFeatureFileKinds.contains)) {
    return null;
  }
  return match.group(2);
}

/// What to do with a file named [fileName] that is not in [feature]'s closed
/// set — the name it should have, spelled out, so the fix is the next step
/// and not a second finding.
String dwServerFeatureFileFix(String feature, String fileName) {
  if (!fileName.endsWith('.dart')) {
    return 'a feature holds Dart files only — move it out of lib/src/';
  }
  final kinds = dwServerFeatureFileKinds;
  final stem = fileName.substring(0, fileName.length - '.dart'.length);
  final kindMatch = RegExp('^(.*)_(${kinds.join('|')})\$').firstMatch(stem);
  // What the file is about, without the feature's prefix (or a near miss of
  // it: `course_` in `courses/`) and without any kind's name.
  String topic(String base) {
    var segments = base.split('_');
    if (base.startsWith('${feature}_') || base == feature) {
      segments = base == feature
          ? const []
          : base.substring(feature.length + 1).split('_');
    } else if (segments.isNotEmpty &&
        segments.first.isNotEmpty &&
        (feature.startsWith(segments.first) ||
            segments.first.startsWith(feature))) {
      segments = segments.sublist(1);
    }
    return segments.where((s) => s.isNotEmpty && !kinds.contains(s)).join('_');
  }

  if (kindMatch == null) {
    return 'move it to $feature/$dwServerFeatureLogicFolder/$fileName, '
        'or into the kind file it is (${feature}_<kind>.dart, kind one of '
        '${kinds.join(', ')})';
  }
  final kind = kindMatch.group(2)!;
  if (kind == 'feature') {
    return 'a feature declares itself once, in ${feature}_feature.dart — '
        'fold this into it';
  }
  final about = topic(kindMatch.group(1)!);
  final renamed = about.isEmpty
      ? '${feature}_$kind.dart'
      : '${feature}_${about}_$kind.dart';
  final logicName = about.isEmpty ? kindMatch.group(1)! : about;
  return 'rename it to $renamed; if it holds no $kind, it is logic: '
      '$feature/$dwServerFeatureLogicFolder/$logicName.dart';
}

/// What a server feature's folder holds, and which file holds what
/// ([DwCheckType.invalidServerFeatureFile], [DwCheckType.misplacedServerCode];
/// dartway/dartway#381).
///
/// The top level of `lib/src/` is [DwLayoutInspector]'s. Inside a feature,
/// every project on the framework had invented a layout of its own — `rows/`,
/// `handlers/` and `domain/` subfolders in one, mappers and publishing in
/// `core/` in the next, a job, eight handlers and a mapper in one file in the
/// third — so the same question had three answers and an agent copying any of
/// them spread its own. Names alone would not hold it: a file named
/// `_handlers` proves nothing about where handlers are, so what a file
/// declares is read too.
class DwServerFeatureInspector {
  DwServerFeatureInspector({
    required this.serverPackageDir,
    this.sharedPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _filesEnabled = _enabled(
         DwCheckType.invalidServerFeatureFile,
         filterType,
         filterSeverity,
       ),
       _codeEnabled = _enabled(
         DwCheckType.misplacedServerCode,
         filterType,
         filterSeverity,
       );

  final Directory? serverPackageDir;

  /// Where the data objects are declared; without it, row → data object
  /// mapping is not looked for.
  final Directory? sharedPackageDir;

  final bool _filesEnabled;
  final bool _codeEnabled;
  final _fileFindings = <String>[];
  final _codeFindings = <String>[];

  static bool _enabled(
    DwCheckType type,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  ) =>
      (filterType == null || filterType == type) &&
      (filterSeverity == null || filterSeverity == type.severity);

  /// [DwCheckType.invalidServerFeatureFile]'s findings.
  List<String> get fileFindings => List.unmodifiable(_fileFindings);

  /// [DwCheckType.misplacedServerCode]'s findings.
  List<String> get codeFindings => List.unmodifiable(_codeFindings);

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (server == null || (!_filesEnabled && !_codeEnabled)) return 0;
    final src = Directory(p.join(server.path, 'lib', 'src'));
    if (!src.existsSync()) return 0;
    final label = '${p.basename(server.path)}/lib/src';

    for (final entity in _sorted(src)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.') || name == 'migrations') continue;
      if (name == 'core') {
        if (_filesEnabled) _checkFolderNames(entity, '$label/core');
      } else if (dwServerForbiddenFolders.contains(name) ||
          !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
        // A layer or a malformed name at the top is the layout's finding,
        // and what it holds is judged once it has a feature to belong to.
        continue;
      } else if (_filesEnabled) {
        _checkFeatureFolder(entity, name, '$label/$name');
      }
      if (_codeEnabled) _checkCode(entity, name, label);
    }

    final count = _fileFindings.length + _codeFindings.length;
    // Said rather than passed over: without the data objects, a mapper in the
    // wrong file is invisible, and a clean run would claim otherwise.
    if (_codeEnabled && _objects.isEmpty) {
      print(
        '\n  ℹ️ INFO: row → data object mapping not checked: '
        '${_sharedLib == null ? 'no shared package found' : 'the shared package declares no data objects'}',
      );
    }
    if (count == 0) return 0;
    print('\n🧱 Server features:\n');
    for (final finding in _fileFindings) {
      print('  ${DwCheckType.invalidServerFeatureFile.reportLabel}: $finding');
    }
    for (final finding in _codeFindings) {
      print('  ${DwCheckType.misplacedServerCode.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.invalidServerFeatureFile, _fileFindings.length);
    tally?.add(DwCheckType.misplacedServerCode, _codeFindings.length);
    return count;
  }

  String get _kinds => dwServerFeatureFileKinds.join(', ');

  void _checkFeatureFolder(Directory dir, String feature, String label) {
    for (final entity in _sorted(dir)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        if (name == dwServerFeatureLogicFolder) {
          _checkLogic(entity, feature, '$label/$name');
        } else {
          _fileFindings.add(
            '$label/$name/ — a feature has one subfolder, '
            '$dwServerFeatureLogicFolder/; '
            '${dwServerForbiddenFolders.contains(name) ? '`$name` is a layer, and ' : ''}'
            'its files go to ${feature}_<kind>.dart or '
            '$feature/$dwServerFeatureLogicFolder/',
          );
        }
        continue;
      }
      // A generated part is named after its source, and moves with it.
      if (name.endsWith('.dw.dart')) continue;
      if (dwServerFeatureFileKind(feature, name) != null) continue;
      _fileFindings.add(
        '$label/$name — not ${feature}_<kind>.dart or '
        '${feature}_<part>_<kind>.dart (kind one of $_kinds, a part never a '
        'kind): ${dwServerFeatureFileFix(feature, name)}',
      );
    }
  }

  void _checkLogic(Directory dir, String feature, String label) {
    for (final entity in _sorted(dir)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        // Logic that needs grouping is a feature too big for one folder: it
        // splits into features, or into `<part>` files.
        _fileFindings.add(
          '$label/$name/ — $dwServerFeatureLogicFolder/ is flat'
          '${dwServerForbiddenFolders.contains(name) ? ', and `$name` is a layer name' : ''}; '
          'logic that needs grouping means the feature is too big — split it '
          'into features, or into ${feature}_<part>_<kind>.dart files',
        );
        continue;
      }
      final kind = RegExp(
        '_(${dwServerFeatureFileKinds.join('|')})\\.dart\$',
      ).firstMatch(name)?.group(1);
      if (kind == null) continue;
      _fileFindings.add(
        '$label/$name — $dwServerFeatureLogicFolder/ holds what is not one '
        'of the kinds, and its names carry no kind\'s suffix: '
        '${dwServerFeatureFileFix(feature, name).replaceFirst('rename it to ', 'move it beside the feature\'s others as ')}',
      );
    }
  }

  /// Layer names at any depth below [dir].
  void _checkFolderNames(Directory dir, String label) {
    for (final entity in _sorted(dir)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (dwServerForbiddenFolders.contains(name)) {
        _fileFindings.add(_layerFolder('$label/$name'));
      } else {
        _checkFolderNames(entity, '$label/$name');
      }
    }
  }

  String _layerFolder(String path) =>
      '$path/ — `${p.basename(path)}` is a layer name, forbidden at any depth '
      'of lib/src/ (${(dwServerForbiddenFolders.toList()..sort()).join(', ')}): '
      'rows, handlers, objects and publications are files of their feature, '
      'and the rest is its $dwServerFeatureLogicFolder/';

  // --- What a file declares -------------------------------------------------

  /// A declaration of a handler: `DwCallHandler.command<…>(` or a handler
  /// list `<DwCallHandler>[`.
  static final _handler = RegExp(
    r'\bDwCallHandler\s*\.\s*\w+\s*(?:<[^;]*?>)?\s*\(|<\s*DwCallHandler\s*>\s*\[',
  );

  /// A row class: `@DwSqlTable(` or `extends DwTableRow`.
  static final _row = RegExp(r'@DwSqlTable\s*\(|\bextends\s+DwTableRow\b');

  /// A job kind or definition constructed.
  static final _job = RegExp(
    r'\b(?:DwQueuedJob|DwRecurringJob|DwJobKind)\s*(?:<[^;]*?>)?\s*\(',
  );

  /// A door declared: `DwHttpRoute.post(` or a `<DwHttpRoute>[` list.
  static final _route = RegExp(
    r'\bDwHttpRoute\s*\.\s*\w+\s*\(|<\s*DwHttpRoute\s*>\s*\[',
  );

  static final _serverFeature = RegExp(r'\bDwServerFeature\s*\(');

  /// `ctx.publish(`, `ctx..publish(` — a publish on a context, not a static
  /// of the project's own type that happens to share the name
  /// (`PostPublisher.publish(`).
  static final _publish = RegExp(r'(?<!\b[A-Z][\w$]*\s*)\.publish\s*\(');

  static final _rowType = RegExp(r'\b[A-Z]\w*Row\b');

  Set<String>? _dataObjects;

  Directory? get _sharedLib {
    final shared = sharedPackageDir;
    if (shared == null) return null;
    final lib = Directory(p.join(shared.path, 'lib'));
    return lib.existsSync() ? lib : null;
  }

  /// The data objects the shared package declares: classes extending
  /// `DwDataObject`, directly or through a base of the project's own.
  Set<String> get _objects => _dataObjects ??= () {
    final lib = _sharedLib;
    if (lib == null) return <String>{};
    final extendsOf = <String, String>{};
    final declaration = RegExp(
      r'\bclass\s+(\w+)\s*(?:<[^{]*?>)?\s+extends\s+(\w+)',
    );
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.dw.dart')) {
        continue;
      }
      final code = dwBlankNonCode(file.readAsStringSync());
      for (final match in declaration.allMatches(code)) {
        extendsOf[match.group(1)!] = match.group(2)!;
      }
    }
    bool isObject(String name, [int depth = 0]) {
      final base = extendsOf[name];
      if (base == null || depth > 16) return false;
      return base == 'DwDataObject' || isObject(base, depth + 1);
    }

    return {
      for (final name in extendsOf.keys)
        if (isObject(name)) name,
    };
  }();

  void _checkCode(Directory top, String topName, String srcLabel) {
    final isCore = topName == 'core';
    final files = top.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = file.path;
      if (!path.endsWith('.dart') || path.endsWith('.dw.dart')) continue;
      final rel = p.relative(path, from: top.path).replaceAll(r'\', '/');
      if (rel.split('/').any((segment) => segment.startsWith('.'))) continue;
      final inLogic = rel.startsWith('$dwServerFeatureLogicFolder/');
      final name = p.basename(path);
      final kind = isCore || inLogic
          ? null
          : RegExp(
              '_(${dwServerFeatureFileKinds.join('|')})\\.dart\$',
            ).firstMatch(name)?.group(1);
      final isDeclaration =
          !isCore && !inLogic && rel == '${topName}_feature.dart';
      final feature = isCore ? '<feature>' : topName;
      final label = '$srcLabel/$topName/$rel';

      final outline = DwDartOutline(file.readAsStringSync());
      final code = outline.code;

      void misplaced(RegExp pattern, String what, String allowedKind) {
        final match = pattern.firstMatch(code);
        if (match == null) return;
        _codeFindings.add(
          '$label:${outline.lineOf(match.start)} declares $what — '
          '${isCore ? 'core/ holds none; ' : ''}they live in '
          '${feature}_$allowedKind.dart or ${feature}_<part>_$allowedKind.dart',
        );
      }

      if (kind != 'handlers') misplaced(_handler, 'handlers', 'handlers');
      if (kind != 'rows') misplaced(_row, 'row classes', 'rows');
      if (kind != 'jobs') misplaced(_job, 'jobs or job kinds', 'jobs');
      if (kind != 'routes') misplaced(_route, 'routes (DwHttpRoute)', 'routes');
      if (!isDeclaration) {
        final match = _serverFeature.firstMatch(code);
        if (match != null) {
          _codeFindings.add(
            '$label:${outline.lineOf(match.start)} declares a DwServerFeature '
            '— a feature declares itself once, in '
            '${isCore ? '<feature>/<feature>' : '$topName/$topName'}_feature.dart',
          );
        }
      }

      final objects = _objects;
      DwDeclaredFunction? publication;
      DwDeclaredFunction? mapping;
      for (final function in outline.functions) {
        if (outline.ownMatches(function, _publish).isNotEmpty) {
          publication ??= function;
          continue;
        }
        if (objects.isEmpty) continue;
        final takesRow =
            _rowType.hasMatch(function.parameters) ||
            (function.enclosingType?.endsWith('Row') ?? false) ||
            (function.extendedType?.endsWith('Row') ?? false);
        if (!takesRow) continue;
        // A closure field with an inferred type says nothing before its
        // name; what it builds decides.
        final returnsObject =
            (function.isField && function.returnType.isEmpty) ||
            RegExp(r'\b[A-Z]\w*')
                .allMatches(function.returnType)
                .any((m) => objects.contains(m[0]));
        if (!returnsObject) continue;
        // Built here, not handed on: a publication answering what another
        // one built maps nothing.
        final body = code.substring(function.bodyStart, function.bodyEnd);
        final constructsObject = RegExp(
          r'\b([A-Z]\w*)\s*(?:\.\s*\w+\s*)?\(',
        ).allMatches(body).any((m) => objects.contains(m[1]));
        if (constructsObject) mapping ??= function;
      }
      if (kind != 'publications' && publication != null) {
        _codeFindings.add(
          '$label:${outline.lineOf(publication.offset)} declares a '
          'publication (`${publication.name}` publishes) — '
          '${isCore ? 'core/ holds none; ' : ''}publications live in '
          '${feature}_publications.dart or ${feature}_<part>_publications.dart',
        );
      }
      if (kind != 'objects' && mapping != null) {
        _codeFindings.add(
          '$label:${outline.lineOf(mapping.offset)} maps a row to a data '
          'object (`${mapping.name}`) — '
          '${isCore ? 'core/ holds none; ' : ''}mapping lives in '
          '${feature}_objects.dart or ${feature}_<part>_objects.dart',
        );
      }
    }
  }

  static List<FileSystemEntity> _sorted(Directory dir) =>
      dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
}
