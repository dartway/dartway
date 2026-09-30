import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';
import 'dw_feature_tree.dart';

/// One way to show a read, a spinner, a dialog, a route and a new thing, in a
/// Flutter app's `lib/` (dartway/dartway#390).
///
/// - [DwCheckType.forbiddenRequestRead]: a widget shows a read through
///   `DwReadBuilder` (or `DwPagedListView`, `DwWindowListView`), so the
///   result of `ref.watch(dw.request|pages|table|window(…))` taken apart by
///   hand — a member of it (`.value`, `.when(`, `.hasError`, …), a `switch`
///   or `case` over it (`AsyncError(…)`), a `.select` of the read, the values
///   of a `ref.listen` over it — is refused outside `logic/` and the files of
///   `core/` that declare no widget, where a provider may derive its own
///   state from a read.
/// - [DwCheckType.forbiddenProgressIndicator]: Flutter's progress
///   indicators outside `ui_kit/` — loading is the kit's, through
///   `DwFlutterConfig.readLoadingBuilder` or a kit widget.
/// - [DwCheckType.forbiddenNavigationCall]: `showDialog`,
///   `showModalBottomSheet`, `showCupertino…` and their siblings,
///   `Navigator.push…`, `MaterialPageRoute` and the other page routes outside
///   `ui_kit/` and `core/router/`; and `Navigator.pop`, `GoRouter.pop`,
///   `context.pop` anywhere.
/// - [DwCheckType.sentinelId]: a route parameter set to `0` or `-1`
///   (`AdminParams.courseId.set(0)`). A new thing is its own route, not an
///   id nobody has.
///
/// Read from the source with comments and strings blanked, so a word in a
/// doc comment is not code. What a text scan cannot see is left out on
/// purpose: a read reached through a provider of the project's own
/// (`myProfileProvider` over `dw.request`) or handed to a function before it
/// is taken apart; an id in a command's constructor (`SaveCourse(id: 0)` —
/// the same text as the stand-in data a skeleton is drawn from) or compared
/// with `0` in a page; `Navigator.of(context).pop` on a page; a focus-once
/// notifier standing in for a route parameter.
class DwFlutterUiInspector {
  DwFlutterUiInspector({
    required this.flutterPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
  }) : _active = {
         for (final type in checks)
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  /// The checks this inspector answers for.
  static const checks = [
    DwCheckType.forbiddenRequestRead,
    DwCheckType.forbiddenProgressIndicator,
    DwCheckType.forbiddenNavigationCall,
    DwCheckType.sentinelId,
  ];

  final Directory flutterPackageDir;

  /// When set, only this folder is judged (relative to the package).
  final String? targetDirPath;

  final Set<DwCheckType> _active;
  final _findings = <DwUiFinding>[];

  /// What this run found, in file order.
  List<DwUiFinding> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    if (_active.isEmpty) return 0;
    final lib = Directory(p.join(flutterPackageDir.path, 'lib'));
    if (!lib.existsSync()) return 0;
    final scope = targetDirPath == null
        ? null
        : p
              .relative(
                p.isAbsolute(targetDirPath!)
                    ? targetDirPath!
                    : p.join(flutterPackageDir.path, targetDirPath!),
                from: lib.path,
              )
              .replaceAll(r'\', '/');

    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final rel = p.relative(file.path, from: lib.path).replaceAll(r'\', '/');
      if (_isGenerated(rel)) continue;
      if (scope != null && rel != scope && !rel.startsWith('$scope/')) {
        continue;
      }
      _findings.addAll(
        judge(
          rel,
          file.readAsStringSync(),
        ).where((finding) => _active.contains(finding.type)),
      );
    }

    if (_findings.isEmpty) return 0;
    print('\n📌 Reads, loading, dialogs and routes:\n');
    for (final finding in _findings) {
      print('  ${finding.type.reportLabel}: $finding');
    }
    for (final type in _active) {
      tally?.add(type, _findings.where((f) => f.type == type).length);
    }
    return _findings
        .where((f) => f.type.severity == DwCheckSeverity.error)
        .length;
  }

  static bool _isGenerated(String rel) =>
      rel.endsWith('.g.dart') ||
      rel.endsWith('.gen.dart') ||
      rel.endsWith('.freezed.dart') ||
      rel.endsWith('.dw.dart') ||
      p.posix.split(rel).any(dwIgnoredFolders.contains);

  /// Judges one file of `lib/`, [rel] being its path under `lib/`.
  static List<DwUiFinding> judge(String rel, String content) {
    final code = DwDartSource(content).code;
    final findings = <DwUiFinding>[];
    int lineOf(int offset) =>
        '\n'.allMatches(content.substring(0, offset)).length + 1;
    void add(DwCheckType type, int offset, String message) =>
        findings.add(DwUiFinding(type, rel, lineOf(offset), message));

    final segments = p.posix.split(rel);
    final folders = segments.sublist(0, segments.length - 1);
    final inCore = segments.first == 'core';
    final inKit = segments.first == 'ui_kit';
    final inRouter = inCore && folders.length > 1 && folders[1] == 'router';

    // ------------------------------------------------------------- reads
    // `core/` is wiring — a provider over a read, the router's state — but a
    // widget in it is a screen like any other.
    final wiring = inCore && !_widgetClass.hasMatch(code);
    if (!wiring && !folders.contains('logic')) {
      for (final (offset, what) in _rawReads(code)) {
        add(
          DwCheckType.forbiddenRequestRead,
          offset,
          what == '.select'
              ? '.select of a read in a widget — a value the screen needs '
                    'whatever the read answers (a title, an enabled button, '
                    'a badge) is a provider in the feature\'s logic/ that '
                    'selects from the read and answers a plain value with a '
                    'fallback'
              : '$what of a read taken apart by hand — show it with '
                    'DwReadBuilder(dw.request(…), builder: …): loading, '
                    'refusal branches (onRefused), failure and retry in one '
                    'place; a list read page by page is DwPagedListView; a '
                    'value the chrome needs is a logic/ provider answering a '
                    'plain value',
        );
      }
    }

    // ----------------------------------------------------------- spinners
    if (!inKit) {
      for (final match in _spinner.allMatches(code)) {
        add(
          DwCheckType.forbiddenProgressIndicator,
          match.start,
          '${match.group(1)} outside ui_kit/ — a read loads through '
          'DwFlutterConfig.readLoadingBuilder (or a placeholder skeleton); '
          'any other wait is a kit widget',
        );
      }
    }

    // ---------------------------------------------------- dialogs, routes
    if (!inKit && !inRouter) {
      for (final match in _dialog.allMatches(code)) {
        add(
          DwCheckType.forbiddenNavigationCall,
          match.start,
          '${match.group(1)} outside ui_kit/ — open a dialog or a sheet '
          'through the kit (showAppBottomSheet, a kit dialog), or confirm '
          'with dw.action(confirmation: …)',
        );
      }
      for (final match in _push.allMatches(code)) {
        add(
          DwCheckType.forbiddenNavigationCall,
          match.start,
          '${match.group(0)!.replaceAll(RegExp(r'\s'), '')}… outside '
          'ui_kit/ and core/router/ — a screen is a route of a zone: '
          'GoRouter.of(context).goNamed(Zone.route.name, pathParameters: …)',
        );
      }
    }
    for (final match in _wrongPop.allMatches(code)) {
      add(
        DwCheckType.forbiddenNavigationCall,
        match.start,
        '${match.group(0)!.replaceAll(RegExp(r'\s'), '')} — a page goes '
        'back with GoRouter.of(context).goNamed(<parent>.name) or the AppBar\'s '
        'leading button; a dialog or a sheet closes with '
        'Navigator.of(context).pop(…), the builder\'s own context',
      );
    }

    // ----------------------------------------------------------- sentinels
    for (final match in _sentinel.allMatches(code)) {
      add(
        DwCheckType.sentinelId,
        match.start,
        '${match.group(0)!.replaceAll(RegExp(r'\s+'), ' ')} — 0 and -1 are '
        'not ids: "new" is a route of its own (a .simple route beside the '
        '.parameterized one), and "none" is null',
      );
    }

    findings.sort((a, b) => a.line.compareTo(b.line));
    return findings;
  }

  // ------------------------------------------------------------------ reads

  /// `dw.request(`, `dw.pages(`, `dw.table(`, `dw.window(`.
  static final _dwRead = RegExp(
    r'(?<![\w$])dw\s*\.\s*(?:request|pages|table|window)\s*(?:<[^()]*>)?\s*\(',
  );

  /// `ref.watch(` / `ref.read(`.
  static final _refLook = RegExp(r'(?<![\w$])ref\s*\.\s*(?:watch|read)\s*\(');

  /// Every place a read's `AsyncValue` is taken apart: the offset, and what.
  static List<(int, String)> _rawReads(String code) {
    final found = <(int, String)>[];

    // Names bound to a read's provider: `final request = dw.request(…);`.
    final providers = <String>{};
    for (final match in RegExp(
      r'(?<![\w$])(?:final|var|const)\s+(?:\w+(?:<[^=;]*>)?\s+)?(\w+)\s*=\s*',
    ).allMatches(code)) {
      if (_dwRead.matchAsPrefix(code, match.end) != null) {
        providers.add(match.group(1)!);
      }
    }

    bool isReadProvider(String argument) {
      final trimmed = argument.trim();
      if (trimmed.endsWith('.notifier')) return false;
      if (_dwRead.matchAsPrefix(trimmed) != null) {
        final open = trimmed.indexOf('(');
        final close = _closing(trimmed, open);
        final rest = trimmed.substring(close).trim();
        // `dw.request(r)` itself, or `.select(…)` of it — a value read
        // through a selector is taken apart all the same.
        return rest.isEmpty || rest.startsWith('.select');
      }
      if (providers.contains(trimmed)) return true;
      final selected = RegExp(
        r'^(\w+)\s*\.\s*select\b',
      ).firstMatch(trimmed)?.group(1);
      return selected != null && providers.contains(selected);
    }

    // `ref.watch(<read>)` — what follows the call, and the name it is bound to.
    final values = <(String, int)>[];
    for (final match in _refLook.allMatches(code)) {
      final open = match.end - 1;
      final close = _closing(code, open);
      final argument = code.substring(open + 1, close - 1);
      if (!isReadProvider(argument)) continue;
      if (argument.contains('.select')) {
        found.add((match.start, '.select'));
        continue;
      }
      final after = RegExp(r'\s*(\?\.|\.)\s*(\w+)').matchAsPrefix(code, close);
      if (after != null) {
        found.add((match.start, '.${after.group(2)}'));
        continue;
      }
      final binding = _binding.firstMatch(
        code.substring(match.start < 200 ? 0 : match.start - 200, match.start),
      );
      if (binding != null) values.add((binding.group(1)!, match.start));
    }

    // `ref.listen(<read>, (previous, next) { … })` — the callback's values
    // are the read's, taken apart the same way.
    for (final match in RegExp(
      r'(?<![\w$])ref\s*\.\s*listen(?:Manual)?\s*(?:<[^()]*>)?\s*\(',
    ).allMatches(code)) {
      final open = match.end - 1;
      final firstEnd = _argumentEnd(code, open + 1);
      final argument = code.substring(open + 1, firstEnd);
      if (!isReadProvider(argument)) continue;
      if (argument.contains('.select')) {
        found.add((match.start, '.select'));
        continue;
      }
      final callback = RegExp(
        r'\s*,\s*\(\s*(?:[\w<>?]+\s+)?(\w+)\s*,\s*(?:[\w<>?]+\s+)?(\w+)\s*\)',
      ).matchAsPrefix(code, firstEnd);
      if (callback == null) continue;
      final span = _closureSpan(code, callback.end - 2);
      if (span == null) continue;
      for (final name in [callback.group(1)!, callback.group(2)!]) {
        if (name == '_') continue;
        values.add((name, span.$1));
      }
    }

    // Uses of a bound value within its block: a member, a switch, a case —
    // but not inside a closure whose parameter takes the same name
    // (`builder: (card) => card.profile`).
    for (final (name, at) in values) {
      final end = _blockEnd(code, at);
      final shadowed = <(int, int)>[
        for (final parameter in RegExp(
          '[(,]\\s*(?:final\\s+)?(?:[\\w<>?]+\\s+)?${RegExp.escape(name)}'
          '\\s*(?=[,)])',
        ).allMatches(code.substring(at, end)))
          if (_closureSpan(code, at + parameter.start) case final span?) span,
      ];
      final uses = RegExp(
        '(?<![\\w\$.])(?:switch\\s*\\(\\s*${RegExp.escape(name)}\\s*\\)'
        '|${RegExp.escape(name)}\\s*(?:(\\?\\.|\\.)\\s*(\\w+)|case\\b|is\\s+Async))',
      );
      for (final use in uses.allMatches(code.substring(at, end))) {
        final offset = at + use.start;
        if (shadowed.any((span) => offset >= span.$1 && offset < span.$2)) {
          continue;
        }
        final text = use.group(0)!;
        final what = use.group(2) != null
            ? '.${use.group(2)}'
            : text.startsWith('switch')
            ? 'a switch'
            : text.contains('case')
            ? 'a case pattern'
            : 'an is-check';
        found.add((offset, what));
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return found;
  }

  /// The span of the closure whose parameter list holds the parameter at
  /// [at] (a `(` or `,` before it), or `null` when that list is no closure's.
  static (int, int)? _closureSpan(String code, int at) {
    var open = at;
    var depth = 0;
    for (; open >= 0; open--) {
      final char = code[open];
      if (char == ')') depth++;
      if (char == '(') {
        if (depth == 0) break;
        depth--;
      }
    }
    if (open < 0) return null;
    // `switch (x) {`, `if (x) {` — a statement, not a closure's parameters.
    if (RegExp(
      r'(?:^|[^\w$])(?:switch|if|while|for|catch)\s*$',
    ).hasMatch(code.substring(open < 12 ? 0 : open - 12, open))) {
      return null;
    }
    final close = _closing(code, open);
    final arrow = RegExp(r'\s*(?:async\s*)?(=>|\{)').matchAsPrefix(code, close);
    if (arrow == null) return null;
    if (arrow.group(1) == '{') {
      return (close, _closing(code, arrow.end - 1));
    }
    // An expression body ends at the first `,`, `;` or unmatched closer.
    var level = 0;
    for (var i = arrow.end; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') level++;
      if (char == ')' || char == ']' || char == '}') {
        if (level == 0) return (close, i);
        level--;
      }
      if ((char == ',' || char == ';') && level == 0) return (close, i);
    }
    return (close, code.length);
  }

  /// A binding right before a `ref.watch(`: `final x =`, `var x =`,
  /// `AsyncValue<Invoice> x =`, `final AsyncValue<Invoice> x =`.
  static final _binding = RegExp(
    r'(?<![\w$.])(?:(?:final|var)\s+)?(?:[A-Za-z_]\w*(?:<[^=;{}]*>)?\??\s+)?'
    r'(\w+)\s*=\s*$',
  );

  /// A class of the file is a widget or a widget's state.
  static final _widgetClass = RegExp(
    r'(?<![\w$])class\s+\w+[^{;]*?\bextends\s+(?:\w+\.)?'
    r'(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget'
    r'|HookWidget|HookConsumerWidget|StatefulHookWidget'
    r'|StatefulHookConsumerWidget|State\s*<|ConsumerState\s*<)',
  );

  /// Where the argument starting at [from] ends: the first comma at its own
  /// depth, or the closing parenthesis of the call.
  static int _argumentEnd(String code, int from) {
    var depth = 0;
    for (var i = from; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') depth++;
      if (char == ')' || char == ']' || char == '}') {
        if (depth == 0) return i;
        depth--;
      }
      if (char == ',' && depth == 0) return i;
    }
    return code.length;
  }

  /// Where the block enclosing [offset] closes.
  static int _blockEnd(String code, int offset) {
    var depth = 0;
    for (var i = offset; i >= 0; i--) {
      final char = code[i];
      if (char == '}') depth++;
      if (char == '{') {
        if (depth == 0) return _closing(code, i);
        depth--;
      }
    }
    return code.length;
  }

  // ------------------------------------------------------- the other checks

  static final _spinner = RegExp(
    r'(?<![\w$])(CircularProgressIndicator|LinearProgressIndicator'
    r'|RefreshProgressIndicator|CupertinoActivityIndicator)'
    r'\s*(?:\.\s*adaptive\s*)?\(',
  );

  static final _dialog = RegExp(
    r'(?<![\w$])(show(?:Dialog|GeneralDialog|AdaptiveDialog|ModalBottomSheet'
    r'|BottomSheet|Cupertino\w+))\s*(?:<[^()]*>)?\s*\(',
  );

  static final _push = RegExp(
    r'(?<![\w$])(?:Navigator\s*\.\s*(?:(?:of|maybeOf)\s*\([^()]*\)\s*\??\.\s*)?'
    r'push\w*|(?:Material|Cupertino)PageRoute|PageRouteBuilder|DialogRoute'
    r'|ModalBottomSheetRoute|RawDialogRoute)\s*(?:<[^()]*>)?\s*\(',
  );

  /// Pops spelled other than `Navigator.of(context).pop(`.
  static final _wrongPop = RegExp(
    r'(?<![\w$])(?:Navigator\s*\.\s*pop|GoRouter\s*\.\s*of\s*\([^()]*\)\s*\.\s*pop'
    r'|context\s*\.\s*pop)\s*(?:<[^()]*>)?\s*\(',
  );

  /// A route parameter set to `0` or `-1`: `AdminParams.courseId.set(0)` —
  /// the parameter enums are `…Params` (or `…Param`), which is what tells a
  /// route parameter from `DwFieldPatch.set(0)` or any other `set`.
  static final _sentinel = RegExp(
    r'(?<![\w$])\w*Params?\s*\.\s*\w+\s*\.\s*set\s*\(\s*(?:0|-\s*1)\s*\)',
  );

  /// The offset just past the bracket closing the one at [open].
  static int _closing(String code, int open) {
    final opener = code[open];
    final closer = switch (opener) {
      '{' => '}',
      '(' => ')',
      _ => ']',
    };
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      final char = code[i];
      if (char == opener) depth++;
      if (char == closer && --depth == 0) return i + 1;
    }
    return code.length;
  }
}

/// A finding of [DwFlutterUiInspector]: the check, where, and what to do.
final class DwUiFinding {
  const DwUiFinding(this.type, this.file, this.line, this.message);

  final DwCheckType type;

  /// The path under `lib/`.
  final String file;
  final int line;
  final String message;

  @override
  String toString() => 'lib/$file:$line — $message';
}
