import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_feature_tree.dart';
import 'dw_layout.dart';

/// One way to hold state and one way to send a command, in a Flutter app's
/// `lib/` (dartway/dartway#389).
///
/// [DwCheckType.forbiddenStateHolder]: widget-local state is hooks, state
/// shared between widgets or a flow is a Riverpod `Notifier` — so a
/// `StatefulWidget` (and its `State`, `setState`, `StatefulBuilder`), a
/// `ChangeNotifier` or a `ValueNotifier` held as state is refused anywhere in
/// `lib/` but generated code. The one way past it is [allowMarker] on the line
/// above the class, with a reason: the class (and, for a widget, its `State`)
/// is then passed over, and the run counts and lists it.
///
/// [DwCheckType.forbiddenCommandCall]: `dw.command` is sent from a feature's
/// `logic/` only and never inside a `try`; a widget runs a feature's
/// `<Feature>Commands` only inside `dw.action`, and never reads a result
/// (`DwCallOk`, `DwCallRefused`, `DwCallFailed`, `valueOrThrow`) — `dw.action`
/// does, and shows a refusal through the app's catalogue.
///
/// [DwCheckType.routerDisposedByApp]: `<x>.router.dispose` — the app disposing
/// its `DwAppRouter`'s `GoRouter`, which disposes itself with its provider
/// (dartway/dartway#407).
///
/// Read from the source with comments and strings blanked, so a word in a doc
/// comment is not code. What a text scan cannot see is left out on purpose:
/// a flow controller's method called outside `dw.action` (its name says
/// nothing), a state holder reached through a type alias or a subclass of our
/// own, and whether a `Notifier` is named `<Thing>Controller`.
class DwFlutterStateInspector {
  DwFlutterStateInspector({
    required this.flutterPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
    this.targetDirPath,
  }) : _active = {
         for (final type in const [
           DwCheckType.forbiddenStateHolder,
           DwCheckType.forbiddenCommandCall,
           DwCheckType.routerDisposedByApp,
         ])
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  /// The escape hatch, written on the line above a class (doc comments and
  /// annotations may sit between): `// dw:allow-stateful <reason>`.
  static const allowMarker = 'dw:allow-stateful';

  final Directory flutterPackageDir;

  /// When set, only this folder is judged (relative to the package).
  final String? targetDirPath;

  final Set<DwCheckType> _active;
  final _findings = <DwStateFinding>[];
  final _allowances = <String>[];

  /// What this run found, in file order.
  List<DwStateFinding> get findings => List.unmodifiable(_findings);

  /// Every class passed over by [allowMarker], as `file:line — reason`.
  List<String> get allowances => List.unmodifiable(_allowances);

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
      final judged = judge(rel, file.readAsStringSync());
      _findings.addAll(judged.findings.where((f) => _active.contains(f.type)));
      if (_active.contains(DwCheckType.forbiddenStateHolder)) {
        _allowances.addAll(judged.allowances);
      }
    }

    if (_findings.isEmpty && _allowances.isEmpty) return 0;
    print('\n📌 State, commands and the router:\n');
    for (final finding in _findings) {
      print('  ${finding.type.reportLabel}: $finding');
    }
    for (final allowance in _allowances) {
      print('  🔓 $allowMarker: $allowance');
    }
    for (final type in _active) {
      tally?.add(type, _findings.where((f) => f.type == type).length);
    }
    for (final allowance in _allowances) {
      tally?.allow(allowance);
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
  static DwJudgedFile judge(String rel, String content) {
    final code = blankCommentsAndStrings(content);
    final findings = <DwStateFinding>[];
    final allowances = <String>[];
    int lineOf(int offset) =>
        '\n'.allMatches(content.substring(0, offset)).length + 1;
    void add(DwCheckType type, int offset, String message) =>
        findings.add(DwStateFinding(type, rel, lineOf(offset), message));

    // ------------------------------------------------------- state holders
    final classes = _classesIn(code);
    final marked = _markedClasses(content, classes);
    for (final problem in marked.problems) {
      add(DwCheckType.forbiddenStateHolder, problem.$1, problem.$2);
    }
    final exempt = <(int, int)>[];
    for (final declaration in classes) {
      // flutter_hooks' own API for a custom hook: its setState is the hook's.
      if (declaration.base == 'HookState') {
        exempt.add((declaration.start, declaration.end));
        continue;
      }
      final allowedWidget = marked.reasons.containsKey(declaration.name);
      final allowedState =
          declaration.typeArgument != null &&
          _isStateClass(declaration) &&
          marked.reasons.containsKey(declaration.typeArgument);
      if (allowedWidget || allowedState) {
        exempt.add((declaration.start, declaration.end));
      }
    }
    for (final MapEntry(key: name, value: (offset, reason))
        in marked.reasons.entries) {
      allowances.add('$rel:${lineOf(offset)} $name — $reason');
    }
    bool isExempt(int offset) =>
        exempt.any((span) => offset >= span.$1 && offset < span.$2);

    final reported = <(int, int)>[];
    for (final declaration in classes) {
      if (isExempt(declaration.start)) continue;
      final base = declaration.base;
      final String? why;
      if (_statefulBases.contains(base)) {
        why =
            '${declaration.name} is a $base — local state is hooks: '
            'HookWidget/HookConsumerWidget with useTextEditingController, '
            'useFocusNode, useAnimationController, useEffect (cleanup '
            'returned), useState; didUpdateWidget is a useEffect keyed on '
            'the prop';
      } else if (_isStateClass(declaration) &&
          classes.any(
            (c) =>
                c.name == declaration.typeArgument &&
                _statefulBases.contains(c.base),
          )) {
        // Its widget, declared here, carries the finding for both.
        reported.add((declaration.start, declaration.end));
        continue;
      } else if (_isStateClass(declaration)) {
        why =
            '${declaration.name} is a $base — local state is hooks '
            '(HookWidget/HookConsumerWidget), not a State class';
      } else if (_notifierBases.contains(base) ||
          declaration.mixins.any(_notifierBases.contains)) {
        why =
            '${declaration.name} is a ${_notifierBases.contains(base) ? base : 'ChangeNotifier'} '
            '— state shared between widgets is a Riverpod Notifier named '
            '<Thing>Controller in the feature\'s logic/; state of one widget '
            'is a hook';
      } else {
        why = null;
      }
      if (why == null) continue;
      reported.add((declaration.start, declaration.end));
      add(DwCheckType.forbiddenStateHolder, declaration.start, why);
    }
    bool isReported(int offset) =>
        reported.any((span) => offset >= span.$1 && offset < span.$2);
    for (final match in _looseStateUse.allMatches(code)) {
      if (isExempt(match.start) || isReported(match.start)) continue;
      final what = match.group(0)!.replaceAll(RegExp(r'\s'), '');
      add(
        DwCheckType.forbiddenStateHolder,
        match.start,
        what.startsWith('setState')
            ? 'setState — local state is a hook (useState), in a '
                  'HookWidget/HookConsumerWidget'
            : what.startsWith('StatefulBuilder')
            ? 'StatefulBuilder — local state is a hook, in a '
                  'HookWidget/HookConsumerWidget'
            : '${what.replaceAll('(', '')} held as state — useState/'
                  'useValueNotifier for one widget, a Riverpod Notifier for '
                  'state several share',
      );
    }

    // ------------------------------------------------------------ commands
    final segments = p.posix.split(rel);
    final inZone = dwFlutterZones.contains(segments.first);
    final inLogic =
        inZone &&
        segments.length > 2 &&
        segments.sublist(1, segments.length - 1).contains('logic');

    // `core/` is app-wide wiring with no button — a push token, a bootstrap
    // step — and may send what no feature owns.
    final inCore = segments.first == 'core';
    for (final match in _dwCommand.allMatches(code)) {
      if (!inLogic && !inCore) {
        add(
          DwCheckType.forbiddenCommandCall,
          match.start,
          'dw.command outside a feature\'s logic/ (or core/) — send it from '
          'logic/<feature>_commands.dart (or the flow\'s controller) and '
          'run it inside the dw.action of the widget that owns the button',
        );
      }
    }

    for (final tryBlock in _tryBlocks(code)) {
      final body = code.substring(tryBlock.$1, tryBlock.$2);
      final sends =
          _dwCommand.firstMatch(body) ?? _commandsCall.firstMatch(body);
      if (sends == null) continue;
      add(
        DwCheckType.forbiddenCommandCall,
        tryBlock.$1,
        'a command inside try/catch — dw.action catches it and shows a refusal '
        'through the app\'s refusal texts; return the result instead',
      );
    }

    if (!inLogic && !inCore) {
      for (final match in _resultRead.allMatches(code)) {
        add(
          DwCheckType.forbiddenCommandCall,
          match.start,
          '${match.group(0)!.replaceAll(RegExp(r'[\s.]'), '')} read outside '
          'logic/ — dw.action reads a result and shows a refusal; a value the '
          'widget needs is unwrapped in logic/ and arrives in '
          'followUpIfMountedAction',
        );
      }
      final actions = _firstArgumentSpans(code, _dwAction);
      for (final match in _commandsCall.allMatches(code)) {
        if (actions.any((s) => match.start >= s.$1 && match.start < s.$2)) {
          continue;
        }
        add(
          DwCheckType.forbiddenCommandCall,
          match.start,
          '${match.group(1)}.${match.group(2)} runs outside dw.action — wrap '
          'it: dw.action((_) => ${match.group(1)}.${match.group(2)}(…))',
        );
      }
    }

    // ------------------------------------------------------ router lifetime
    for (final match in _routerDispose.allMatches(code)) {
      add(
        DwCheckType.routerDisposedByApp,
        match.start,
        'the app disposes its router — DwAppRouter disposes itself with the '
        'provider that built it (ref:), so delete this line; left in, it is a '
        'second dispose that fails in debug',
      );
    }

    findings.sort((a, b) => a.line.compareTo(b.line));
    return DwJudgedFile(findings, allowances);
  }

  static const _statefulBases = {
    'StatefulWidget',
    'ConsumerStatefulWidget',
    'StatefulHookWidget',
    'StatefulHookConsumerWidget',
  };
  static const _stateBases = {'State', 'ConsumerState'};

  /// `extends State<W>` — the type argument is what makes it Flutter's: a
  /// project's own `State` enum or class is not.
  static bool _isStateClass(_ClassDeclaration declaration) =>
      _stateBases.contains(declaration.base) &&
      declaration.typeArgument != null;
  static const _notifierBases = {'ChangeNotifier', 'ValueNotifier'};

  /// `setState(`, `StatefulBuilder(`, and a `ValueNotifier`/`ChangeNotifier`
  /// constructed — outside a class already reported for being one.
  static final _looseStateUse = RegExp(
    r'(?<![\w$.])(?:setState\s*\(|StatefulBuilder\s*\(|'
    r'(?:ValueNotifier|ChangeNotifier)\s*(?:<[^()]*>)?\s*\()',
  );

  static final _dwCommand = RegExp(r'(?<![\w$])dw\s*\.\s*command\b');
  static final _dwAction = RegExp(
    r'(?<![\w$])dw\s*\.\s*action\s*(?:<[^()]*>)?\s*\(',
  );

  /// `<Feature>Commands.method(` — the canon's name for what sends commands.
  static final _commandsCall = RegExp(
    r'(?<![\w$.])([A-Z]\w*Commands)\s*\.\s*(\w+)\s*\(',
  );

  /// `.router.dispose`, called or torn off: the `GoRouter` of a `DwAppRouter`.
  static final _routerDispose = RegExp(r'\.\s*router\s*\.\s*dispose\b');

  static final _resultRead = RegExp(
    r'(?<![\w$])(?:DwCallOk|DwCallRefused|DwCallFailed)\b|\.\s*valueOrThrow\b',
  );

  static final _classHeader = RegExp(
    r'(?<![\w$])class\s+(\w+)(?:\s*<[^{]*?>)?\s*'
    r'(?:extends\s+(?:\w+\.)?(\w+)\s*(?:<\s*(\w+))?[^{;]*?)?'
    r'(?:with\s+([\w\s,<>?]+?))?(?:implements\s+[^{]*?)?\{',
  );

  static List<_ClassDeclaration> _classesIn(String code) => [
    for (final match in _classHeader.allMatches(code))
      _ClassDeclaration(
        name: match.group(1)!,
        base: match.group(2),
        typeArgument: match.group(3),
        mixins: (match.group(4) ?? '')
            .split(',')
            .map((m) => m.replaceAll(RegExp(r'<.*'), '').trim())
            .where((m) => m.isNotEmpty)
            .toList(),
        start: match.start,
        end: _closing(code, match.end - 1),
      ),
  ];

  /// Markers above classes: which class each allows, and why; and what is
  /// wrong with a marker that allows nothing.
  static ({Map<String, (int, String)> reasons, List<(int, String)> problems})
  _markedClasses(String content, List<_ClassDeclaration> classes) {
    final reasons = <String, (int, String)>{};
    final problems = <(int, String)>[];
    final marker = RegExp(
      '^([ \\t]*)//[ \\t]*${RegExp.escape(allowMarker)}\\b[ \\t:—-]*(.*)\$',
      multiLine: true,
    );
    final comments = lineCommentStarts(content);
    for (final match in marker.allMatches(content)) {
      // Text that only looks like the marker — inside a string or a block
      // comment — is not one.
      if (!comments.contains(match.start + match.group(1)!.length)) continue;
      final reason = match.group(2)!.trim();
      // The class this marker sits on: the first declaration after it with
      // only comments, annotations and blank lines between.
      final after = content.substring(match.end);
      final gap = RegExp(
        r'^(?:\s*(?://[^\n]*|/\*[\s\S]*?\*/|@\w+(?:\([^)]*\))?))*\s*',
      ).firstMatch(after)!;
      final at = match.end + gap.end;
      final declaration = classes
          .where((c) => c.start == at || _abstractAt(content, at, c.start))
          .firstOrNull;
      if (declaration == null) {
        problems.add((
          match.start,
          '$allowMarker allows nothing — it belongs on the line above the '
              'class it allows',
        ));
      } else if (reason.isEmpty) {
        problems.add((
          match.start,
          '$allowMarker on ${declaration.name} gives no reason — say why '
              'hooks or a Notifier cannot hold this state',
        ));
      } else {
        reasons[declaration.name] = (match.start, reason);
      }
    }
    return (reasons: reasons, problems: problems);
  }

  /// `abstract class`, `final class` and the like: modifiers before the
  /// keyword the declaration's match starts at.
  static bool _abstractAt(String content, int at, int classStart) =>
      classStart > at &&
      RegExp(
        r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)+$',
      ).hasMatch(content.substring(at, classStart));

  /// The spans of `try { … }` bodies that something catches — a
  /// `try`/`finally` lets the refusal through to `dw.action`.
  static List<(int, int)> _tryBlocks(String code) => [
    for (final match in RegExp(r'(?<![\w$])try\s*\{').allMatches(code))
      if (_closing(code, match.end - 1) case final end
          when _catchClause.matchAsPrefix(code, end) != null)
        (match.end - 1, end),
  ];

  static final _catchClause = RegExp(r'\s*(?:catch\s*\(|on\s+[A-Za-z_])');

  /// The span of the first argument of every call [opening] matches (ending
  /// in `(`) — the work `dw.action` runs, not `followUpIfMountedAction` or the
  /// other named arguments after it.
  static List<(int, int)> _firstArgumentSpans(String code, RegExp opening) => [
    for (final match in opening.allMatches(code))
      (match.end, _firstArgumentEnd(code, match.end - 1)),
  ];

  /// Where the first argument of the call whose `(` is at [open] ends: the
  /// first comma at its own depth, or the closing parenthesis.
  static int _firstArgumentEnd(String code, int open) {
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') depth++;
      if (char == ')' || char == ']' || char == '}') {
        if (--depth == 0) return i;
      }
      if (char == ',' && depth == 1) return i;
    }
    return code.length;
  }

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

  /// [content] with every comment and every string's contents replaced by
  /// spaces, newlines kept — so an offset in the result is the same offset in
  /// [content], and a bracket inside a string or a comment is not code.
  /// Interpolations are blanked with the string around them.
  static String blankCommentsAndStrings(String content) =>
      _DwSourceBlanker(content).run();

  /// Where each real `//` comment of [content] starts — not one inside a
  /// string or a block comment.
  static Set<int> lineCommentStarts(String content) =>
      (_DwSourceBlanker(content)..run()).lineCommentStarts;
}

/// A finding of [DwFlutterStateInspector]: the check, where, and what to do.
final class DwStateFinding {
  const DwStateFinding(this.type, this.file, this.line, this.message);

  final DwCheckType type;

  /// The path under `lib/`.
  final String file;
  final int line;
  final String message;

  @override
  String toString() => 'lib/$file:$line — $message';
}

/// What [DwFlutterStateInspector.judge] says about one file.
final class DwJudgedFile {
  const DwJudgedFile(this.findings, this.allowances);

  final List<DwStateFinding> findings;

  /// The classes passed over by the marker, as `file:line Class — reason`.
  final List<String> allowances;
}

final class _ClassDeclaration {
  const _ClassDeclaration({
    required this.name,
    required this.base,
    required this.typeArgument,
    required this.mixins,
    required this.start,
    required this.end,
  });

  final String name;
  final String? base;
  final String? typeArgument;
  final List<String> mixins;
  final int start;
  final int end;
}

/// The scanner behind [DwFlutterStateInspector.blankCommentsAndStrings].
final class _DwSourceBlanker {
  _DwSourceBlanker(this.content) : out = content.split('');

  final String content;
  final List<String> out;
  final lineCommentStarts = <int>{};

  String run() {
    var i = 0;
    while (i < content.length) {
      if (content.startsWith('//', i)) {
        lineCommentStarts.add(i);
        final end = content.indexOf('\n', i);
        final stop = end < 0 ? content.length : end;
        _blank(i, stop);
        i = stop;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final close = content.indexOf('*/', i + 2);
        final stop = close < 0 ? content.length : close + 2;
        _blank(i, stop);
        i = stop;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        final quoteLength = content.startsWith(char * 3, i) ? 3 : 1;
        final end = _skipString(i);
        _blank(i + quoteLength, end - quoteLength);
        i = end;
        continue;
      }
      i++;
    }
    return out.join();
  }

  void _blank(int from, int to) {
    for (var i = from; i < to && i < out.length; i++) {
      if (out[i] != '\n') out[i] = ' ';
    }
  }

  /// Past the string whose opening quote is at [start]; an `r` before the
  /// quote makes it raw. A one-quote string ends at the line's end at most.
  int _skipString(int start) {
    final raw =
        start > 0 &&
        content[start - 1] == 'r' &&
        (start < 2 || !RegExp(r'[\w$]').hasMatch(content[start - 2]));
    final quote = content[start];
    final delimiter = content.startsWith(quote * 3, start) ? quote * 3 : quote;
    var i = start + delimiter.length;
    while (i < content.length) {
      if (content.startsWith(delimiter, i)) return i + delimiter.length;
      if (!raw && content[i] == r'\') {
        i += 2;
        continue;
      }
      if (delimiter.length == 1 && content[i] == '\n') return i;
      if (!raw && content.startsWith(r'${', i)) {
        i = _skipInterpolation(i + 1);
        continue;
      }
      i++;
    }
    return content.length;
  }

  /// Past the `}` closing the interpolation whose `{` is at [open], stepping
  /// over the strings nested in it.
  int _skipInterpolation(int open) {
    var depth = 0;
    var i = open;
    while (i < content.length) {
      final char = content[i];
      if (char == "'" || char == '"') {
        i = _skipString(i);
        continue;
      }
      if (char == '{') depth++;
      if (char == '}' && --depth == 0) return i + 1;
      i++;
    }
    return content.length;
  }
}
