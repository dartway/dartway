import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:pub_semver/pub_semver.dart';

import '../project_locale.dart';
import '../toolkit_manifest.dart';
import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';
import 'dw_feature_tree.dart';
import 'dw_project_template.dart';

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
/// `generated/`, `l10n/`, and any file whose header says it was generated —
/// `firebase_options.dart`) are nobody's code and are passed over.
class DwUniformityInspector {
  DwUniformityInspector({
    required this.projectRoot,
    required this.flutterPackageDir,
    this.serverPackageDir,
    this.sharedPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
    this.template,
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

  /// The skeleton the project was created from. A doc comment it holds
  /// verbatim is the skeleton's, not the project's, and is not judged for
  /// language; without it every doc comment is, and the run says so.
  final DwProjectTemplate? template;

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
    if (_active.contains(DwCheckType.docCommentLanguage) &&
        language != null &&
        template == null) {
      _notes.add(
        'docCommentLanguage judged every doc comment: no checkout of the '
        'framework is at hand to tell the skeleton\'s own from the project\'s',
      );
    }
    if (_active.contains(DwCheckType.docCommentLanguage) && language == null) {
      _notes.add(
        'docCommentLanguage not judged: .agents/dartway-toolkit.json records '
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
        if (isGeneratedText(content)) continue;

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
          final inherited = template?.fileFor(
            '${p.basename(package.path)}/lib/$rel',
          );
          final wrong = docCommentsNotIn(
            content,
            language,
            inherited: inherited == null
                ? const {}
                : {
                    for (final (_, text) in _docCommentBlocks(inherited))
                      _norm(text),
                  },
          );
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
        'test/<path>/<folder>/<folder>[_<scenario>]_acceptance_test.dart for '
        'lib/<path>/<folder>/); helpers live in test/support/; `dartway check '
        '--fix` moves root-level acceptance tests',
    DwCheckType.testHarnessBypassed:
        'one harness per side, in test/support/, extended and never bypassed',
    DwCheckType.rawSpacing:
        'spacing outside ui_kit/ is a step of the kit\'s scale, named by value '
        '— Gap(AppSpace.s12), EdgeInsets.all(AppSpace.s16); a value the scale '
        'lacks becomes a step, never a rounded neighbour',
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
  /// `<folder>[_<scenario>]_acceptance_test.dart` at the mirror of that
  /// folder: `test/src/chat/chat_acceptance_test.dart` or
  /// `chat_attachments_acceptance_test.dart` for `lib/src/chat/`, the
  /// `<feature>_*` naming the files of a feature follow. Everything else a
  /// test needs is a helper, and helpers live in `test/support/`.
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
      final owner = p.posix.basename(folder);
      if (folder != '.' &&
          (name == owner || name.startsWith('${owner}_')) &&
          libDirectoryExists(folder)) {
        return null;
      }
      return 'an acceptance test sits at the mirror of the folder it tests and '
          'is named after it: test/<path>/<folder>/<folder>[_<scenario>]'
          '_acceptance_test.dart for lib/<path>/<folder>/ (a scenario across '
          'features names the feature that owns it)'
          '${folder == '.' ? ' — `dartway check --fix` moves one whose lib/src/<folder>/ exists' : ''}';
    }
    final mirrored =
        '${rel.substring(0, rel.length - '_test.dart'.length)}.dart';
    if (libFileExists(mirrored)) return null;
    return 'mirrors nothing: no lib/$mirrored';
  }

  // ---------------------------------------------------------------- imports

  /// Rewrites every relative import and export in `lib/` of [packages] to its
  /// `package:` form, sorts the import block of each file it touched (see
  /// [sortedImports]), and answers what it rewrote as `path:line`. With
  /// [onlyUnder], only the files under that folder are touched. Generated
  /// files are left to their generator, and a URI that climbs out of `lib/`
  /// to its author.
  static List<String> fixRelativeImports(
    List<Directory> packages, {
    Directory? onlyUnder,
  }) {
    final rewritten = <String>[];
    for (final package in packages) {
      final lib = Directory(p.join(package.path, 'lib'));
      final packageName = _packageName(package);
      if (!lib.existsSync() || packageName == null) continue;
      for (final file in _dartFiles(lib)) {
        if (onlyUnder != null &&
            !p.isWithin(p.absolute(onlyUnder.path), p.absolute(file.path))) {
          continue;
        }
        final rel = _posix(p.relative(file.path, from: lib.path));
        if (_isGenerated(rel)) continue;
        final content = file.readAsStringSync();
        if (isGeneratedText(content)) continue;
        final fixed = packageImportsFor(content, rel, packageName);
        if (fixed.lines.isEmpty) continue;
        file.writeAsStringSync(sortedImports(fixed.content));
        rewritten.addAll(
          fixed.lines.map(
            (line) => '${p.basename(package.path)}/lib/$rel:$line',
          ),
        );
      }
    }
    return rewritten;
  }

  /// Moves each acceptance test lying at the root of `test/` to the mirror of
  /// the folder it is named after — `test/<x>[_<scenario>]_acceptance_test.dart`
  /// to `test/src/<x>/` when `lib/src/<x>/` exists — and rewrites its relative
  /// imports (the harness in `test/support/`) for the new place. Answers
  /// `from → to` per move. Nothing else is moved: which file a plain test
  /// mirrors is not something its name tells.
  static List<String> fixTestLayout(List<Directory> packages) {
    final moved = <String>[];
    for (final package in packages) {
      final test = Directory(p.join(package.path, 'test'));
      final src = Directory(p.join(package.path, 'lib', 'src'));
      if (!test.existsSync() || !src.existsSync()) continue;
      final features =
          src
              .listSync()
              .whereType<Directory>()
              .map((dir) => p.basename(dir.path))
              .toList()
            // The longest name first, so `chat_files` wins over `chat`.
            ..sort((a, b) => b.length.compareTo(a.length));
      final files = test.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final name = p.basename(file.path);
        if (!name.endsWith('_acceptance_test.dart')) continue;
        final stem = name.substring(
          0,
          name.length - '_acceptance_test.dart'.length,
        );
        final owner = features
            .where((f) => stem == f || stem.startsWith('${f}_'))
            .firstOrNull;
        if (owner == null) continue;
        final target = File(p.join(test.path, 'src', owner, name));
        if (target.existsSync()) continue;
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(
          relocatedImports(
            file.readAsStringSync(),
            from: '.',
            to: 'src/$owner',
          ),
        );
        file.deleteSync();
        moved.add(
          '${p.basename(package.path)}/test/$name → test/src/$owner/$name',
        );
      }
    }
    return moved;
  }

  /// [content] of a file moved from the folder [from] to the folder [to]
  /// (both relative to one root, `/`-separated), its relative URIs rewritten
  /// to reach what they reached before.
  static String relocatedImports(
    String content, {
    required String from,
    required String to,
  }) {
    final edits = <(int, int, String)>[];
    for (final directive in _directivesIn(content)) {
      for (final uri in directive.uris) {
        if (!_isRelative(uri.value)) continue;
        final target = p.posix.normalize(p.posix.join(from, uri.value));
        edits.add((uri.start, uri.end, p.posix.relative(target, from: to)));
      }
    }
    var result = content;
    for (final (start, end, value) in edits.reversed) {
      result = result.replaceRange(start, end, value);
    }
    return result;
  }

  /// [content] with its leading block of single-line `import` directives
  /// sorted as `directives_ordering` wants: `dart:`, then `package:` by URI,
  /// then relative ones, a blank line between the groups. A block
  /// interleaved with comments, or holding a directive over several lines,
  /// is left as it is — its order may be saying something.
  static String sortedImports(String content) {
    final lines = content.split('\n');
    final first = lines.indexWhere((line) => line.startsWith('import '));
    if (first < 0) return content;
    var last = first;
    for (var i = first; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.isEmpty) continue;
      if (!_singleLineImport.hasMatch(line)) break;
      last = i;
    }
    final block = [
      for (final line in lines.sublist(first, last + 1))
        if (line.trim().isNotEmpty) line.trimRight(),
    ];
    String uriOf(String line) => _uriLiteral.firstMatch(line)!.group(2)!;
    List<String> group(bool Function(String uri) test) =>
        block.where((line) => test(uriOf(line))).toList()
          ..sort((a, b) => uriOf(a).compareTo(uriOf(b)));
    final groups = [
      group((uri) => uri.startsWith('dart:')),
      group((uri) => uri.contains(':') && !uri.startsWith('dart:')),
      group((uri) => !uri.contains(':')),
    ].where((group) => group.isNotEmpty);
    return [
      ...lines.sublist(0, first),
      for (final (index, group) in groups.indexed) ...[
        if (index > 0) '',
        ...group,
      ],
      ...lines.sublist(last + 1),
    ].join('\n');
  }

  static final _singleLineImport = RegExp(
    r'''^import\s+(['"])[^'"]*\1(\s+(as|show|hide|deferred)\b[^;]*)?;$''',
  );

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

  /// A URI with no scheme — `dart:`, `package:` and `file:` all name one.
  static bool _isRelative(String uri) => !uri.contains(':');

  /// `import`/`export` directives: found in the text with comments and
  /// strings blanked, so a directive quoted inside a multi-line string is not
  /// one. Each directive's URI literals — the first, and each one right after
  /// an `if (…)`; a literal inside the condition (`dart.library.io == 'true'`)
  /// is not a URI. `part` and `part of` are not directives this touches.
  static List<_Directive> _directivesIn(String content) {
    final source = DwDartSource(content);
    final bare = source.code;
    final directives = <_Directive>[];
    for (final match in _directiveStart.allMatches(bare)) {
      final end = bare.indexOf(';', match.end);
      if (end < 0) continue;
      final uris = <_Literal>[];
      for (final literal in source.literals) {
        if (literal.start < match.end || literal.end > end) continue;
        if (uris.isNotEmpty &&
            !_afterCondition.hasMatch(
              bare.substring(match.end, literal.start),
            )) {
          continue;
        }
        uris.add(
          _Literal(literal.contentStart, literal.contentEnd, literal.text),
        );
      }
      directives.add(_Directive(uris));
    }
    return directives;
  }

  /// The text before a conditional URI: it ends with `if (…)`.
  static final _afterCondition = RegExp(r'\bif\s*\([^;]*\)\s*$');

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
  ///
  /// A block in [inherited] — the normalized blocks of the skeleton's own copy
  /// of the file — is the skeleton's and is passed over. `{@macro}` and
  /// `{@template}` markers and indented code examples are not prose. In a
  /// language written in another script, quoted text is UI copy being
  /// described rather than the comment's language, and is removed too.
  static List<int> docCommentsNotIn(
    String content,
    String language, {
    Set<String> inherited = const {},
  }) {
    final expectCyrillic = _cyrillicLanguages.contains(language);
    final wrong = <int>[];
    for (final (line, text) in _docCommentBlocks(content)) {
      if (inherited.contains(_norm(text))) continue;
      var prose = text
          .replaceAll(RegExp(r'~~~[\s\S]*?~~~'), ' ')
          .replaceAll(RegExp(r'^(?: {5,}|\t).*$', multiLine: true), ' ')
          .replaceAll(RegExp(r'\{@(?:macro|template|endtemplate)[^}]*\}'), ' ')
          .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
          .replaceAll(RegExp(r'`[^`]*`'), ' ')
          .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
          .replaceAll(RegExp(r'https?://\S+'), ' ');
      if (!expectCyrillic) {
        prose = prose.replaceAllMapped(
          _quoted,
          (quote) => _cyrillic.hasMatch(quote[0]!) ? ' ' : quote[0]!,
        );
      }
      final cyrillic = _cyrillic.allMatches(prose).length;
      final latin = RegExp(r'[A-Za-z]').allMatches(prose).length;
      final isWrong = expectCyrillic
          ? cyrillic == 0 && latin >= _minimumLetters
          : cyrillic >= _minimumLetters && cyrillic > latin;
      if (isWrong) wrong.add(line);
    }
    return wrong;
  }

  static final _cyrillic = RegExp(r'[\u0400-\u04FF]');

  /// Text in quotes of any kind on one line — UI copy a comment describes.
  static final _quoted = RegExp(
    '\'[^\'\\n]*\'|"[^"\\n]*"|«[^»\\n]*»|“[^”\\n]*”|„[^“\\n]*“',
  );

  /// A doc comment's text with its spacing collapsed, as compared with the
  /// skeleton's.
  static String _norm(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Whether [content] says in its first lines that a tool wrote it —
  /// `// GENERATED CODE - DO NOT MODIFY`, `// File generated by FlutterFire`.
  static bool isGeneratedText(String content) => RegExp(
    r'^\s*//.*\b(generated by|do not (modify|edit)|generated code)\b',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(content.split('\n').take(10).join('\n'));

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

  /// Every gap or inset written as a number, as (line, what was written): a
  /// spacer `SizedBox(height:|width: n)`, `Gap(n)`, `EdgeInsets.*(… n …)`, and
  /// the `spacing:`, `runSpacing:`, `mainAxisSpacing:` and `crossAxisSpacing:`
  /// arguments of a flex, a `Wrap` or a grid. A number counts wherever it
  /// sits in the value, the branches of a conditional included.
  ///
  /// A `SizedBox` with a `child:`, or with both a `width:` and a `height:`,
  /// and `SizedBox.square`, give something a size — a component's dimension,
  /// not a gap between two things — and are not spacing. Zero is not a step
  /// of a scale but its absence, and passes; `double.infinity` is not a number
  /// literal and passes.
  static List<(int, String)> rawSpacingIn(String content) {
    final code = DwDartSource(content).code;
    final found = <(int, int, String)>[];
    void report(int start, int end) {
      final written = content
          .substring(start, end)
          .replaceAll(RegExp(r'\s+'), ' ');
      found.add((
        start,
        _lineOf(content, start),
        written.length > 60 ? '${written.substring(0, 57)}…' : written,
      ));
    }

    for (final match in _spacingCall.allMatches(code)) {
      final open = match.end - 1;
      final close = _closing(code, open);
      if (close < 0) continue;
      final arguments = code.substring(open + 1, close);
      final name = match.group(1)!.replaceAll(RegExp(r'\s'), '');
      final bool raw;
      if (name == 'SizedBox') {
        final own = _topLevel(arguments);
        final width = _namedValue(own, 'width');
        final height = _namedValue(own, 'height');
        raw =
            !RegExp(r'(?<![\w$])child\s*:').hasMatch(own) &&
            (width == null || height == null) &&
            _hasNumber(width ?? height ?? '');
      } else {
        raw = _hasNumber(arguments);
      }
      if (raw) report(match.start, close + 1);
    }
    for (final match in _spacingArgument.allMatches(code)) {
      final value = _valueAfter(code, match.end);
      if (_hasNumber(value)) {
        report(match.start, match.end + value.trimRight().length);
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, line, what) in found) (line, what)];
  }

  static final _spacingArgument = RegExp(
    r'(?<![\w$.])(?:spacing|runSpacing|mainAxisSpacing|crossAxisSpacing)'
    r'\s*:(?!:)',
  );

  static bool _hasNumber(String expression) =>
      RegExp('(?<![\\w\$.])$_nonZeroNumber').hasMatch(expression);

  /// The value of the named argument [name] in [arguments] (top level only),
  /// or null when it is not given.
  static String? _namedValue(String arguments, String name) {
    final label = RegExp('(?<![\\w\$])$name\\s*:').firstMatch(arguments);
    return label == null ? null : _valueAfter(arguments, label.end);
  }

  /// The expression starting at [from] in [code], up to the comma or bracket
  /// that ends it at its own depth.
  static String _valueAfter(String code, int from) {
    var depth = 0;
    for (var i = from; i < code.length; i++) {
      final char = code[i];
      if ('([{'.contains(char)) depth++;
      if (')]}'.contains(char)) {
        if (depth == 0) return code.substring(from, i);
        depth--;
      }
      if (char == ',' && depth == 0) return code.substring(from, i);
    }
    return code.substring(from);
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
    final code = DwDartSource(content).code;
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
        '`dartway update --plan` checks resolution first; '
        '`dartway update --target <sha>` adds it';
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
    if (plugins is! YamlMap || !plugins.containsKey('dartway_lints')) {
      return 'no `plugins: dartway_lints:` — the framework\'s lint rules are '
          'silently off, and `flutter analyze` stays green without them; $fix';
    }
    final pin = plugins['dartway_lints'];
    final path = pin is YamlMap ? pin['path'] : null;
    final version = pin is YamlMap ? pin['version'] : pin;
    if (path is String && path.trim().isNotEmpty) return null;
    final git = pin is YamlMap ? pin['git'] : null;
    if (git is String && git.trim().isNotEmpty) return null;
    if (git is YamlMap &&
        git['url'] is String &&
        (git['url'] as String).trim().isNotEmpty &&
        ['ref', 'path'].every(
          (key) =>
              !git.containsKey(key) ||
              (git[key] is String &&
                  (key == 'path' || (git[key] as String).trim().isNotEmpty)),
        )) {
      return null;
    }
    if (version is String) {
      try {
        VersionConstraint.parse(version);
        return null;
      } on FormatException {
        return '`dartway_lints: $version` is not a version constraint, so the '
            'analysis server cannot resolve the plugin — $fix';
      }
    }
    return '`dartway_lints:` names neither a version nor a path nor a git source, so the '
        'analysis server loads nothing — $fix';
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
    try {
      final document = loadYaml(pubspec.readAsStringSync());
      final name = document is YamlMap ? document['name'] : null;
      return name is String && name.isNotEmpty ? name : null;
    } on YamlException {
      return null;
    }
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
