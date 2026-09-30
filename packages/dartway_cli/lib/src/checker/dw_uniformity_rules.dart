import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project_locale.dart';
import '../toolkit_manifest.dart';
import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_feature_tree.dart';

/// One finding of [DwUniformityInspector]: a file (package-relative), a line
/// when there is one, and what to do.
final class DwUniformityFinding {
  const DwUniformityFinding(this.type, this.path, this.line, this.message);

  final DwCheckType type;

  /// Relative to the project root when the package is known by its folder,
  /// else to the package.
  final String path;

  /// 1-based, or null when the finding is about the file as a whole.
  final int? line;
  final String message;

  @override
  String toString() => '${line == null ? path : '$path:$line'} — $message';
}

/// One way to write the ordinary things, in every package of a project
/// (dartway/dartway#391, #379, #396):
///
/// - [DwCheckType.relativeImport] — `lib/` of the Flutter, server and shared
///   package imports and exports by `package:` only;
/// - [DwCheckType.docCommentLanguage] — a doc comment in `lib/` is written in
///   the project's language, judged by its script (a warning: a heuristic);
/// - [DwCheckType.testLayout] — a test mirrors a `lib/` path, helpers live in
///   `test/support/`;
/// - [DwCheckType.testHarnessBypassed] — a test outside `test/support/` builds
///   no server and no `ProviderScope` of its own;
/// - [DwCheckType.rawSpacing] — a gap or an inset outside `ui_kit/` is a kit
///   token, not a number;
/// - [DwCheckType.lintsPluginMissing] — the Flutter package enables the
///   `dartway_lints` analyzer plugin.
///
/// Read from the text with comments and strings blanked, so an example in a
/// doc comment is not code. Generated files (`*.dw.dart`, `*.g.dart`,
/// `generated/`, `l10n/`) are nobody's code and are passed over.
class DwUniformityInspector {
  DwUniformityInspector({
    required this.projectRoot,
    required this.flutterPackageDir,
    this.serverPackageDir,
    this.sharedPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
  }) : _active = {
         for (final type in checks)
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  /// The checks this inspector runs.
  static const checks = [
    DwCheckType.relativeImport,
    DwCheckType.docCommentLanguage,
    DwCheckType.testLayout,
    DwCheckType.testHarnessBypassed,
    DwCheckType.rawSpacing,
    DwCheckType.lintsPluginMissing,
  ];

  final Directory projectRoot;
  final Directory flutterPackageDir;
  final Directory? serverPackageDir;
  final Directory? sharedPackageDir;

  /// When set, only this folder of the Flutter package is judged, and only by
  /// the rules that read one file at a time.
  final String? targetDirPath;

  final Set<DwCheckType> _active;
  final _findings = <DwUniformityFinding>[];
  final _notes = <String>[];

  List<DwUniformityFinding> get findings => List.unmodifiable(_findings);

  /// What the run could not judge, said rather than passed.
  List<String> get notes => List.unmodifiable(_notes);

  int run({DwCheckTally? tally}) {
    if (_active.isEmpty) return 0;

    final scoped = targetDirPath != null;
    final language = _projectLanguage();
    if (_active.contains(DwCheckType.docCommentLanguage) && language == null) {
      _notes.add(
        'docCommentLanguage not judged: .claude/dartway-toolkit.json records '
        'no language this check can read — `dartway setup-ai --language '
        '<code>` records one',
      );
    }

    final packages = [
      flutterPackageDir,
      if (!scoped) ?sharedPackageDir,
      if (!scoped) ?serverPackageDir,
    ];
    for (final package in packages) {
      final role = _roleOf(package);
      final lib = Directory(p.join(package.path, 'lib'));
      if (!lib.existsSync()) continue;
      final packageName = _packageName(package);
      for (final file in _dartFiles(lib)) {
        final rel = _posix(p.relative(file.path, from: lib.path));
        if (_isGenerated(rel)) continue;
        if (scoped && package == flutterPackageDir) {
          final scope = _posix(
            p.relative(
              p.isAbsolute(targetDirPath!)
                  ? targetDirPath!
                  : p.join(package.path, targetDirPath!),
              from: lib.path,
            ),
          );
          if (rel != scope && !rel.startsWith('$scope/')) continue;
        }
        final shown = _shown(package, 'lib/$rel');
        final content = file.readAsStringSync();

        if (_active.contains(DwCheckType.relativeImport)) {
          for (final (line, uri) in relativeImportsIn(content)) {
            final target = packageName == null
                ? null
                : packageUriFor(uri, rel, packageName);
            _add(
              DwCheckType.relativeImport,
              shown,
              line,
              target == null
                  ? "'$uri' climbs out of lib/"
                  : "'$uri' → '$target'",
            );
          }
        }
        if (_active.contains(DwCheckType.docCommentLanguage) &&
            language != null) {
          final wrong = docCommentsNotIn(content, language);
          if (wrong.isNotEmpty) {
            _add(
              DwCheckType.docCommentLanguage,
              shown,
              wrong.first,
              '${wrong.length} doc comment${wrong.length == 1 ? '' : 's'} '
              'not in $language',
            );
          }
        }
        if (role == _Role.flutter &&
            _active.contains(DwCheckType.rawSpacing) &&
            !rel.startsWith('ui_kit/')) {
          for (final (line, what) in rawSpacingIn(content)) {
            _add(DwCheckType.rawSpacing, shown, line, what);
          }
        }
      }

      if (!scoped) _checkTests(package, role);
    }

    if (!scoped && _active.contains(DwCheckType.lintsPluginMissing)) {
      final problem = lintsPluginProblem(flutterPackageDir);
      if (problem != null) {
        _add(
          DwCheckType.lintsPluginMissing,
          _shown(flutterPackageDir, 'analysis_options.yaml'),
          null,
          problem,
        );
      }
    }

    if (_findings.isEmpty && _notes.isEmpty) return 0;
    print('\n📐 Imports, comments, tests, spacing:');
    for (final type in checks) {
      final ofType = _findings.where((f) => f.type == type).toList();
      if (ofType.isEmpty) continue;
      print(
        '\n  ${type.reportLabel} ${type.name} (${ofType.length}) — '
        '${_why[type]}',
      );
      for (final finding in ofType) {
        print('    $finding');
      }
    }
    if (_notes.isNotEmpty) print('');
    for (final note in _notes) {
      print('  ⏭️  $note');
    }
    for (final type in checks) {
      tally?.add(type, _findings.where((f) => f.type == type).length);
    }
    return _findings
        .where((f) => f.type.severity == DwCheckSeverity.error)
        .length;
  }

  /// What each check asks for, said once above its findings.
  static const _why = {
    DwCheckType.relativeImport:
        'lib/ imports by package: only; `dartway check --fix` rewrites them',
    DwCheckType.docCommentLanguage:
        "the project's own code is documented in its language; log and error "
        'strings stay English',
    DwCheckType.testLayout:
        'a test mirrors lib/ (test/<path>_test.dart for lib/<path>.dart, '
        'test/<path>/<folder>_acceptance_test.dart for lib/<path>/<folder>/); '
        'helpers live in test/support/',
    DwCheckType.testHarnessBypassed:
        'one harness per side, in test/support/, extended and never bypassed',
    DwCheckType.rawSpacing:
        'spacing outside ui_kit/ is a kit token — Gap(AppSpace.m), '
        'EdgeInsets.all(AppSpace.l) — or a kit widget when the value is one '
        "component's own",
    DwCheckType.lintsPluginMissing:
        "the framework's lint rules are part of its contract",
  };

  void _add(DwCheckType type, String path, int? line, String message) {
    if (!_active.contains(type)) return;
    _findings.add(DwUniformityFinding(type, path, line, message));
  }

  String _shown(Directory package, String rel) =>
      '${p.basename(package.path)}/$rel';

  String? _projectLanguage() {
    final recorded = ToolkitProvenance.read(
      projectRoot,
    )?.setting(ToolkitProvenance.languageSetting);
    return recorded == null ? null : ProjectLocale.codeOf(recorded);
  }

  // ------------------------------------------------------------------ tests

  void _checkTests(Directory package, _Role role) {
    final test = Directory(p.join(package.path, 'test'));
    if (!test.existsSync()) return;
    final lib = p.join(package.path, 'lib');
    for (final file in _dartFiles(test)) {
      final rel = _posix(p.relative(file.path, from: test.path));
      final shown = _shown(package, 'test/$rel');
      if (_active.contains(DwCheckType.testLayout)) {
        final problem = testPathProblem(
          rel,
          libFileExists: (path) => File(p.join(lib, path)).existsSync(),
          libDirectoryExists: (path) =>
              Directory(p.join(lib, path)).existsSync(),
        );
        if (problem != null) {
          _add(DwCheckType.testLayout, shown, null, problem);
        }
      }
      if (_active.contains(DwCheckType.testHarnessBypassed) &&
          !rel.startsWith('support/') &&
          role != _Role.shared) {
        for (final (line, what) in harnessBypassesIn(
          file.readAsStringSync(),
          server: role == _Role.server,
        )) {
          _add(
            DwCheckType.testHarnessBypassed,
            shown,
            line,
            role == _Role.server
                ? '$what — start the server through AppHarness '
                      '(test/support/app_harness.dart)'
                : '$what — run the app through TestApp over FakeApp '
                      '(test/support/app_test_app.dart)',
          );
        }
      }
    }
  }

  /// Why [rel] — a path under `test/` — breaks the test layout, or null.
  ///
  /// A test mirrors what it tests: `test/<p>_test.dart` for `lib/<p>.dart`.
  /// A test of a whole folder — a server feature through its calls — is
  /// `<folder>_acceptance_test.dart` at the mirror of that folder:
  /// `test/src/chat/chat_acceptance_test.dart` for `lib/src/chat/`. Everything
  /// else a test needs is a helper, and helpers live in `test/support/`.
  static String? testPathProblem(
    String rel, {
    required bool Function(String libPath) libFileExists,
    required bool Function(String libPath) libDirectoryExists,
  }) {
    final isTest = rel.endsWith('_test.dart');
    if (rel.startsWith('support/')) {
      return isTest
          ? 'a test inside test/support/ — support holds the harness and '
                'helpers; the test goes to the mirror of the lib/ path it tests'
          : null;
    }
    if (!isTest) {
      return 'a helper outside test/support/ — move it there, beside the '
          'harness, and import it relatively';
    }
    if (rel.endsWith('_acceptance_test.dart')) {
      final folder = p.posix.dirname(rel);
      final name = p.posix
          .basename(rel)
          .substring(
            0,
            p.posix.basename(rel).length - '_acceptance_test.dart'.length,
          );
      if (folder != '.' &&
          p.posix.basename(folder) == name &&
          libDirectoryExists(folder)) {
        return null;
      }
      return 'an acceptance test names the folder it tests and sits at its '
          'mirror: test/<path>/<folder>_acceptance_test.dart for '
          'lib/<path>/<folder>/ — no lib/${folder == '.' ? '' : '$folder/'}'
          ' folder named "$name"';
    }
    final mirrored =
        '${rel.substring(0, rel.length - '_test.dart'.length)}.dart';
    if (libFileExists(mirrored)) return null;
    return 'mirrors nothing: no lib/$mirrored — a test sits at the path of '
        'what it tests (test/<path>_test.dart for lib/<path>.dart), or is '
        'test/<path>/<folder>_acceptance_test.dart for a whole folder';
  }

  // ---------------------------------------------------------------- imports

  /// Rewrites every relative import and export in `lib/` of [packages] to its
  /// `package:` form, and answers what it rewrote as `path:line`. Generated
  /// files are left to their generator, and a URI that climbs out of `lib/`
  /// to its author.
  static List<String> fixRelativeImports(List<Directory> packages) {
    final rewritten = <String>[];
    for (final package in packages) {
      final lib = Directory(p.join(package.path, 'lib'));
      final packageName = _packageName(package);
      if (!lib.existsSync() || packageName == null) continue;
      for (final file in _dartFiles(lib)) {
        final rel = _posix(p.relative(file.path, from: lib.path));
        if (_isGenerated(rel)) continue;
        final fixed = packageImportsFor(
          file.readAsStringSync(),
          rel,
          packageName,
        );
        if (fixed.lines.isEmpty) continue;
        file.writeAsStringSync(fixed.content);
        rewritten.addAll(
          fixed.lines.map(
            (line) => '${p.basename(package.path)}/lib/$rel:$line',
          ),
        );
      }
    }
    return rewritten;
  }

  /// Every relative URI in an `import`/`export` directive of [content], with
  /// its line — a conditional import's alternatives included.
  static List<(int, String)> relativeImportsIn(String content) => [
    for (final directive in _directivesIn(content))
      for (final uri in directive.uris)
        if (_isRelative(uri.value)) (_lineOf(content, uri.start), uri.value),
  ];

  /// [content] with every relative import or export of a file at [rel]
  /// (under `lib/`) rewritten to `package:[packageName]/…`, and the lines it
  /// touched. A URI that climbs out of `lib/` is left for the author.
  static ({String content, List<int> lines}) packageImportsFor(
    String content,
    String rel,
    String packageName,
  ) {
    final edits = <(int, int, String)>[];
    for (final directive in _directivesIn(content)) {
      for (final uri in directive.uris) {
        if (!_isRelative(uri.value)) continue;
        final target = packageUriFor(uri.value, rel, packageName);
        if (target == null) continue;
        edits.add((uri.start, uri.end, target));
      }
    }
    if (edits.isEmpty) return (content: content, lines: const []);
    final lines = {for (final edit in edits) _lineOf(content, edit.$1)};
    var result = content;
    for (final (start, end, target) in edits.reversed) {
      result = result.replaceRange(start, end, target);
    }
    return (content: result, lines: lines.toList()..sort());
  }

  /// `package:[packageName]/…` for [uri] written in the file at [rel] (under
  /// `lib/`), or null when it leads out of `lib/`.
  static String? packageUriFor(String uri, String rel, String packageName) {
    final resolved = p.posix.normalize(p.posix.join(p.posix.dirname(rel), uri));
    if (resolved.startsWith('../') || resolved == '..') return null;
    return 'package:$packageName/$resolved';
  }

  static bool _isRelative(String uri) =>
      !uri.startsWith('package:') && !uri.startsWith('dart:');

  /// `import`/`export` directives, read from the text with comments blanked:
  /// each directive's URI literals — the first, and those after `if (…)`.
  static List<_Directive> _directivesIn(String content) {
    final code = _blankComments(content);
    final directives = <_Directive>[];
    for (final match in _directiveStart.allMatches(code)) {
      final end = code.indexOf(';', match.end);
      if (end < 0) continue;
      // The directive's URIs: the first literal, and each one following
      // `if (…)`. `show`/`hide`/`as` name identifiers, not strings.
      final uris = <_Literal>[
        for (final literal in _uriLiteral.allMatches(
          code.substring(match.end, end),
        ))
          _Literal(
            match.end + literal.start + 1,
            match.end + literal.start + 1 + literal.group(2)!.length,
            literal.group(2)!,
          ),
      ];
      directives.add(_Directive(uris));
    }
    return directives;
  }

  static final _directiveStart = RegExp(
    r'''^[ \t]*(?:import|export)\s+(?=['"])''',
    multiLine: true,
  );

  static final _uriLiteral = RegExp(r'''(['"])([^'"\n]*)\1''');

  // --------------------------------------------------------------- comments

  /// Scripts that the Cyrillic heuristic knows by language code.
  static const _cyrillicLanguages = {
    'ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk', 'ky', 'tg', 'mn', //
  };

  /// The first line of every doc comment in [content] written in a script
  /// other than [language]'s.
  ///
  /// A heuristic on scripts, not languages: a Cyrillic-script language
  /// expects Cyrillic letters in every doc comment that has words at all; any
  /// other language expects a comment not to be mostly Cyrillic. Code spans,
  /// `[references]`, fenced examples and URLs are removed first — an
  /// identifier is not a word of the comment's language.
  static List<int> docCommentsNotIn(String content, String language) {
    final expectCyrillic = _cyrillicLanguages.contains(language);
    final wrong = <int>[];
    for (final (line, text) in _docCommentBlocks(content)) {
      final prose = text
          .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
          .replaceAll(RegExp(r'`[^`]*`'), ' ')
          .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
          .replaceAll(RegExp(r'https?://\S+'), ' ');
      final cyrillic = RegExp(r'[Ѐ-ӿ]').allMatches(prose).length;
      final latin = RegExp(r'[A-Za-z]').allMatches(prose).length;
      final isWrong = expectCyrillic
          ? cyrillic == 0 && latin >= _minimumLetters
          : cyrillic >= _minimumLetters && cyrillic > latin;
      if (isWrong) wrong.add(line);
    }
    return wrong;
  }

  /// Fewer letters than this are a name, not a sentence to judge.
  static const _minimumLetters = 12;

  /// Runs of consecutive `///` lines, as (first line, text).
  static List<(int, String)> _docCommentBlocks(String content) {
    final blocks = <(int, String)>[];
    final lines = content.split('\n');
    int? start;
    final text = StringBuffer();
    for (var i = 0; i <= lines.length; i++) {
      final line = i < lines.length ? lines[i].trimLeft() : '';
      if (i < lines.length && line.startsWith('///')) {
        start ??= i + 1;
        text.writeln(line.substring(3));
        continue;
      }
      if (start != null) {
        blocks.add((start, text.toString()));
        start = null;
        text.clear();
      }
    }
    return blocks;
  }

  // ---------------------------------------------------------------- spacing

  /// Every gap or inset written as a number: a spacer
  /// `SizedBox(height:|width: n)`, `Gap(n)`, `EdgeInsets.*(… n …)`, as (line,
  /// what was written).
  ///
  /// A `SizedBox` with a `child:` sizes that child — a component's dimension,
  /// not a gap between two things — and is not spacing. Zero is not a step of
  /// a scale but its absence, and passes; `double.infinity` is not a number
  /// literal and passes.
  static List<(int, String)> rawSpacingIn(String content) {
    final code = _blankCommentsAndStrings(content);
    final found = <(int, String)>[];
    for (final match in _spacingCall.allMatches(code)) {
      final open = match.end - 1;
      final close = _closing(code, open);
      if (close < 0) continue;
      final arguments = code.substring(open + 1, close);
      final name = match.group(1)!.replaceAll(RegExp(r'\s'), '');
      final bool raw;
      if (name == 'SizedBox') {
        final own = _topLevel(arguments);
        raw =
            !RegExp(r'(?<![\w$])child\s*:').hasMatch(own) &&
            RegExp(
              r'(?<![\w$])(?:height|width)\s*:\s*' + _nonZeroNumber,
            ).hasMatch(own);
      } else {
        raw = RegExp('(?<![\\w\$.])$_nonZeroNumber').hasMatch(arguments);
      }
      if (!raw) continue;
      final written = content
          .substring(match.start, close + 1)
          .replaceAll(RegExp(r'\s+'), ' ');
      found.add((
        _lineOf(content, match.start),
        written.length > 60 ? '${written.substring(0, 57)}…' : written,
      ));
    }
    return found;
  }

  /// A number literal that is not zero, not followed by more of a name.
  static const _nonZeroNumber =
      r'(?!0+(?:\.0+)?(?![\d.]))\d+(?:\.\d+)?(?![\w.])';

  static final _spacingCall = RegExp(
    r'(?<![\w$.])(SizedBox|Gap|SliverGap|'
    r'EdgeInsets(?:Directional)?\s*\.\s*(?:all|symmetric|only|fromLTRB|fromSTEB))'
    r'\s*\(',
  );

  /// [arguments] with every nested bracket's content removed, so a named
  /// argument of an inner call is not read as this call's.
  static String _topLevel(String arguments) {
    final out = StringBuffer();
    var depth = 0;
    for (final char in arguments.split('')) {
      if ('([{'.contains(char)) depth++;
      if (depth == 0) out.write(char);
      if (')]}'.contains(char)) depth--;
    }
    return out.toString();
  }

  // ---------------------------------------------------------------- harness

  /// Where a test builds what the harness owns, as (line, what): a
  /// `ProviderScope` or a `DwFakeServer` in a Flutter test; a `DwTestServer`
  /// or a `DwAppServer` in a server test.
  static List<(int, String)> harnessBypassesIn(
    String content, {
    required bool server,
  }) {
    final code = _blankCommentsAndStrings(content);
    final pattern = server
        ? RegExp(r'(?<![\w$.])(DwTestServer\s*\.\s*start|DwAppServer)\s*\(')
        : RegExp(r'(?<![\w$.])(ProviderScope|DwFakeServer)\s*\(');
    return [
      for (final match in pattern.allMatches(code))
        (
          _lineOf(content, match.start),
          match.group(1)!.replaceAll(RegExp(r'\s'), ''),
        ),
    ];
  }

  // ------------------------------------------------------------------ lints

  /// Why the Flutter package at [flutterPackage] does not run the
  /// `dartway_lints` analyzer plugin, or null when it does.
  static String? lintsPluginProblem(Directory flutterPackage) {
    const fix =
        '`dartway update` adds it, pinned to the channel, as `dartway create` '
        'does';
    final options = File(p.join(flutterPackage.path, 'analysis_options.yaml'));
    if (!options.existsSync()) {
      return 'no analysis_options.yaml, so the dartway_lints analyzer plugin '
          'is off — $fix';
    }
    final Object? document;
    try {
      document = loadYaml(options.readAsStringSync());
    } on YamlException catch (error) {
      return 'analysis_options.yaml does not parse (${error.message}), so the '
          'dartway_lints analyzer plugin is off';
    }
    final plugins = document is YamlMap ? document['plugins'] : null;
    if (plugins is YamlMap && plugins.containsKey('dartway_lints')) {
      return null;
    }
    return 'no `plugins: dartway_lints:` — the framework\'s lint rules are '
        'silently off, and `flutter analyze` stays green without them; $fix';
  }

  // ---------------------------------------------------------------- helpers

  static Iterable<File> _dartFiles(Directory dir) =>
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => !p
                .split(p.relative(file.path, from: dir.path))
                .any((segment) => segment.startsWith('.')),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  static bool _isGenerated(String rel) =>
      rel.endsWith('.g.dart') ||
      rel.endsWith('.gen.dart') ||
      rel.endsWith('.freezed.dart') ||
      rel.endsWith('.dw.dart') ||
      p.posix.split(rel).any(dwIgnoredFolders.contains);

  static String _posix(String path) => path.replaceAll(r'\', '/');

  static int _lineOf(String content, int offset) =>
      '\n'.allMatches(content.substring(0, offset)).length + 1;

  static String? _packageName(Directory package) {
    final pubspec = File(p.join(package.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    return RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
  }

  _Role _roleOf(Directory package) {
    if (package == flutterPackageDir) return _Role.flutter;
    if (package == serverPackageDir) return _Role.server;
    return _Role.shared;
  }

  /// The offset of the bracket closing the one at [open], or -1.
  static int _closing(String code, int open) {
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') depth++;
      if (char == ')' || char == ']' || char == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// [content] with comments replaced by spaces, newlines kept.
  static String _blankComments(String content) =>
      _blank(content, strings: false);

  /// [content] with comments and the insides of string literals replaced by
  /// spaces, newlines kept, so offsets and lines stay where they were.
  static String _blankCommentsAndStrings(String content) =>
      _blank(content, strings: true);

  static String _blank(String content, {required bool strings}) {
    final out = StringBuffer();
    var i = 0;
    String spaces(String text) => text.replaceAll(RegExp(r'[^\n]'), ' ');
    while (i < content.length) {
      if (content.startsWith('//', i)) {
        final end = content.indexOf('\n', i);
        final stop = end < 0 ? content.length : end;
        out.write(spaces(content.substring(i, stop)));
        i = stop;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final end = content.indexOf('*/', i + 2);
        final stop = end < 0 ? content.length : end + 2;
        out.write(spaces(content.substring(i, stop)));
        i = stop;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        final raw = i > 0 && content[i - 1] == 'r';
        final triple = content.startsWith(char * 3, i);
        final delimiter = triple ? char * 3 : char;
        var j = i + delimiter.length;
        while (j < content.length && !content.startsWith(delimiter, j)) {
          if (!triple && content[j] == '\n') break;
          j += (!raw && content[j] == r'\') ? 2 : 1;
        }
        if (j > content.length) j = content.length;
        final closed = content.startsWith(delimiter, j);
        final stop = closed ? j + delimiter.length : j;
        if (strings) {
          out
            ..write(delimiter)
            ..write(spaces(content.substring(i + delimiter.length, j)))
            ..write(closed ? delimiter : '');
        } else {
          out.write(content.substring(i, stop));
        }
        i = stop;
        continue;
      }
      out.write(char);
      i++;
    }
    return out.toString();
  }
}

enum _Role { flutter, server, shared }

final class _Directive {
  const _Directive(this.uris);
  final List<_Literal> uris;
}

final class _Literal {
  const _Literal(this.start, this.end, this.value);
  final int start;
  final int end;
  final String value;
}
