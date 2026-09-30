import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';

/// Ownership checked inline after a rule other than `DwAccessRule.resource`
/// ([DwCheckType.inlineOwnershipCheck], dartway/dartway#387).
///
/// In a server file named `*_handlers.dart`, a handler whose rule is not a
/// resource rule — `signedIn`, a role check, anything else — and which
/// compares an owner field of a row with the caller and refuses `dw.notFound`
/// or `dw.forbidden`, in its own body or in a helper of the same file it
/// calls, is the check `DwAccessRule.resource` makes once. A heuristic, so a
/// warning, and a conservative one:
///
/// - the comparison is `!=` between a field whose name ends in `Id` and names
///   an owner (`owner`, `author`, `user`, `profile`, `account`, `sender`,
///   `recipient`, `creator`, `createdBy`, `member`) and an expression that
///   names the caller (`me`, `my…`, `caller…`, `current…`, `profile`,
///   `accountId`);
/// - it is the condition of an `if` whose branch refuses `notFound` or
///   `forbidden` — or, in a `single` handler, answers `return null`, which the
///   framework refuses `notFound`;
/// - a helper counts only when such a handler of the same file calls it;
/// - a rule is a resource rule when it is `DwAccessRule.resource` itself, or a
///   project function or field (`TasksAccess.ownTask(…)`) whose declaration in
///   the server's `lib/` builds one.
///
/// Comments and strings are not code.
class DwInlineOwnershipInspector {
  DwInlineOwnershipInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.inlineOwnershipCheck) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.inlineOwnershipCheck.severity);

  final Directory? serverPackageDir;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (!_enabled || server == null) return 0;
    final lib = Directory(p.join(server.path, 'lib'));
    if (!lib.existsSync()) return 0;
    final sources =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final resourceRules = {
      for (final file in sources) ...resourceRulesIn(file.readAsStringSync()),
    };
    for (final file in sources.where(
      (f) => f.path.endsWith('_handlers.dart'),
    )) {
      final shown = p.relative(file.path, from: server.parent.path);
      for (final site in inlineOwnershipIn(
        file.readAsStringSync(),
        resourceRules: resourceRules,
      )) {
        _findings.add(
          '${site.helper == null ? 'a handler' : '`${site.helper}`, called by a handler,'} '
          'checks ownership inline — $shown:${site.line}; make it the '
          "handler's DwAccessRule.resource and read the row as ctx.accessed",
        );
      }
    }
    if (_findings.isEmpty) return 0;
    print('\n🔑 Ownership:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.inlineOwnershipCheck.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.inlineOwnershipCheck, _findings.length);
    return 0;
  }

  /// The names of project rules that build a `DwAccessRule.resource` —
  /// `static DwAccessRule ownTask<…>(…) => DwAccessRule.resource…` and
  /// `static final DwAccessRule mine = DwAccessRule.resource…`.
  static Set<String> resourceRulesIn(String content) {
    final code = DwDartSource(content).code;
    final names = <String>{};
    for (final match in _ruleDeclaration.allMatches(code)) {
      // The declaration runs to its `;` where no bracket is open.
      var depth = 0;
      var end = code.length;
      for (var i = match.end; i < code.length; i++) {
        final char = code[i];
        if ('([{'.contains(char)) depth++;
        if (')]}'.contains(char)) depth--;
        if (depth < 0 || (char == ';' && depth == 0)) {
          end = i;
          break;
        }
      }
      if (_resourceRule.hasMatch(code.substring(match.end, end))) {
        names.add(match.group(1)!);
      }
    }
    return names;
  }

  static final _ruleDeclaration = RegExp(r'\bDwAccessRule\s+(\w+)\s*(?=[<(=])');
  static final _resourceRule = RegExp(r'\bDwAccessRule\s*\.\s*resource\b');

  /// The inline ownership checks of one handlers file: the line of each, and
  /// the helper it sits in when it is not in a handler's own body.
  /// [resourceRules] names the project's rules that are resource rules.
  static List<({int line, String? helper})> inlineOwnershipIn(
    String content, {
    Set<String> resourceRules = const {},
  }) {
    final code = DwDartSource(content).code;
    final handlers = _handlers(code, resourceRules);
    final guarded = handlers.where((h) => !h.resource).toList();
    if (guarded.isEmpty) return const [];

    final sites = <({int line, String? helper})>[];
    for (final (:start, :end, :refusesByNull) in _ownerRefusals(code)) {
      final handler = handlers
          .where((h) => h.start <= start && end <= h.end)
          .firstOrNull;
      if (handler != null) {
        final nullCounts = handler.kind == 'single';
        if (!handler.resource && (!refusesByNull || nullCounts)) {
          sites.add((line: _lineOf(code, start), helper: null));
        }
        continue;
      }
      if (refusesByNull) continue;
      final helper = _enclosingFunction(code, start);
      if (helper == null) continue;
      final call = RegExp('\\b${RegExp.escape(helper)}\\s*(<[^>]*>)?\\s*\\(');
      final called = guarded.any(
        (h) => call.hasMatch(code.substring(h.start, h.end)),
      );
      if (called) sites.add((line: _lineOf(code, start), helper: helper));
    }
    return sites;
  }

  static final _handlerStart = RegExp(
    r'\bDwCallHandler\s*\.\s*(single|maybe|list|page|table|window|command)\b',
  );
  static final _access = RegExp(r'\baccess\s*:');

  static List<({int start, int end, String kind, bool resource})> _handlers(
    String code,
    Set<String> resourceRules,
  ) {
    final found = <({int start, int end, String kind, bool resource})>[];
    for (final match in _handlerStart.allMatches(code)) {
      final open = code.indexOf('(', match.end);
      if (open < 0) continue;
      // Type arguments may sit between the factory and its parenthesis.
      final between = code.substring(match.end, open).trim();
      if (between.isNotEmpty && !between.startsWith('<')) continue;
      final close = _matching(code, open);
      if (close < 0) continue;
      final body = code.substring(open, close);
      // The rule is the handler's own `access:`, not one of a nested call.
      final rule = _access
          .allMatches(body)
          .where((m) => _depthAt(body, m.start) == 1)
          .firstOrNull;
      found.add((
        start: open,
        end: close,
        kind: match.group(1)!,
        resource:
            rule != null &&
            _isResource(_argument(body, rule.end), resourceRules),
      ));
    }
    return found;
  }

  /// The expression of an argument starting at [from], up to the `,` or `)`
  /// that ends it.
  static String _argument(String body, int from) {
    var depth = 0;
    for (var i = from; i < body.length; i++) {
      final char = body[i];
      if ('([{<'.contains(char)) depth++;
      if (')]}>'.contains(char)) {
        if (depth == 0) return body.substring(from, i);
        depth--;
      }
      if (char == ',' && depth == 0) return body.substring(from, i);
    }
    return body.substring(from);
  }

  static bool _isResource(String rule, Set<String> resourceRules) {
    if (_resourceRule.hasMatch(rule)) return true;
    final named = RegExp(r'^\s*(?:\w+\s*\.\s*)*(\w+)').firstMatch(rule);
    return named != null && resourceRules.contains(named.group(1));
  }

  static final _ifStart = RegExp(r'\bif\s*\(');

  /// Every `if` whose condition compares an owner field with the caller and
  /// whose branch refuses `notFound`/`forbidden`, or answers `null`.
  static List<({int start, int end, bool refusesByNull})> _ownerRefusals(
    String code,
  ) {
    final found = <({int start, int end, bool refusesByNull})>[];
    for (final match in _ifStart.allMatches(code)) {
      final open = match.end - 1;
      final close = _matching(code, open);
      if (close < 0) continue;
      final condition = code.substring(open + 1, close);
      if (!_comparesOwnerWithCaller(condition)) continue;
      final branch = _branchAfter(code, close + 1);
      if (branch == null) continue;
      final text = code.substring(branch.start, branch.end);
      final refuses =
          RegExp(r'\brefuse\s*\(').hasMatch(text) &&
          RegExp(r'\b(notFound|forbidden)\b').hasMatch(text);
      final answersNull = RegExp(r'\breturn\s+null\s*;').hasMatch(text);
      if (!refuses && !answersNull) continue;
      found.add((start: match.start, end: branch.end, refusesByNull: !refuses));
    }
    return found;
  }

  static final _ownerField = RegExp(
    r'(owner|author|user|profile|account|sender|recipient|creator|createdBy|member)\w*Id$',
    caseSensitive: false,
  );
  static final _caller = RegExp(
    r'(^|[^\w.])(me|my[A-Z]\w*|myId|caller\w*|current[A-Z]\w*)\b'
    r'|\bprofile\b|\baccountId\b|\brequireAccountId\b',
  );

  static bool _comparesOwnerWithCaller(String condition) {
    for (final operand in _splitTopLevel(condition, const ['||', '&&'])) {
      final sides = _splitTopLevel(operand, const ['!=']);
      if (sides.length != 2) continue;
      final left = _unwrap(sides[0]);
      final right = _unwrap(sides[1]);
      if (_isOwnerField(left) && _isCaller(right) && !_isOwnerField(right)) {
        return true;
      }
      if (_isOwnerField(right) && _isCaller(left) && !_isOwnerField(left)) {
        return true;
      }
    }
    return false;
  }

  /// A field read off a row: `row.userProfileId`, `post.authorId` — not the
  /// context's own `ctx.accountId`, which is the caller.
  static bool _isOwnerField(String side) {
    final access = RegExp(r'^([\w?!.()]+)\.(\w+)$').firstMatch(side);
    return access != null &&
        access.group(1) != 'ctx' &&
        access.group(1) != 'this' &&
        _ownerField.hasMatch(access.group(2)!);
  }

  static bool _isCaller(String side) => _caller.hasMatch(side);

  static String _unwrap(String side) {
    var text = side.trim();
    while (text.startsWith('!') && !text.startsWith('!=')) {
      text = text.substring(1).trim();
    }
    return text;
  }

  /// [text] split on [separators] where no bracket is open.
  static List<String> _splitTopLevel(String text, List<String> separators) {
    final parts = <String>[];
    var depth = 0;
    var from = 0;
    var i = 0;
    while (i < text.length) {
      final char = text[i];
      if ('([{'.contains(char)) depth++;
      if (')]}'.contains(char)) depth--;
      if (depth == 0) {
        final separator = separators
            .where((s) => text.startsWith(s, i))
            .firstOrNull;
        if (separator != null) {
          parts.add(text.substring(from, i));
          i += separator.length;
          from = i;
          continue;
        }
      }
      i++;
    }
    parts.add(text.substring(from));
    return parts;
  }

  /// The statement an `if` runs: a block, or one statement up to its `;`.
  static ({int start, int end})? _branchAfter(String code, int from) {
    var i = from;
    while (i < code.length && code[i].trim().isEmpty) {
      i++;
    }
    if (i >= code.length) return null;
    if (code[i] == '{') {
      final close = _matching(code, i);
      return close < 0 ? null : (start: i, end: close + 1);
    }
    var depth = 0;
    for (var j = i; j < code.length; j++) {
      final char = code[j];
      if ('([{'.contains(char)) depth++;
      if (')]}'.contains(char)) depth--;
      if (char == ';' && depth == 0) return (start: i, end: j + 1);
    }
    return null;
  }

  static const _notDeclarations = {
    'if',
    'for',
    'while',
    'switch',
    'catch',
    'return',
    'await',
  };

  /// The name of the innermost function or method whose block body holds
  /// [offset], or `null` when it sits in a closure or at the top level.
  static String? _enclosingFunction(String code, int offset) {
    var depth = 0;
    for (var i = offset - 1; i >= 0; i--) {
      final char = code[i];
      if (char == '}') depth++;
      if (char != '{') continue;
      if (depth > 0) {
        depth--;
        continue;
      }
      // An enclosing block: is it a declaration's body?
      var j = i - 1;
      while (j >= 0 && code[j].trim().isEmpty) {
        j--;
      }
      for (final modifier in const ['async*', 'async', 'sync*']) {
        if (code.substring(0, j + 1).endsWith(modifier)) {
          j -= modifier.length;
          while (j >= 0 && code[j].trim().isEmpty) {
            j--;
          }
          break;
        }
      }
      if (j < 0 || code[j] != ')') continue;
      final open = _matchingBack(code, j);
      if (open < 0) continue;
      var k = open - 1;
      while (k >= 0 && code[k].trim().isEmpty) {
        k--;
      }
      if (k >= 0 && code[k] == '>') {
        var angle = 0;
        for (; k >= 0; k--) {
          if (code[k] == '>') angle++;
          if (code[k] == '<' && --angle == 0) break;
        }
        k--;
        while (k >= 0 && code[k].trim().isEmpty) {
          k--;
        }
      }
      final nameEnd = k + 1;
      while (k >= 0 && RegExp(r'\w').hasMatch(code[k])) {
        k--;
      }
      final name = code.substring(k + 1, nameEnd);
      if (name.isEmpty || _notDeclarations.contains(name)) continue;
      return name;
    }
    return null;
  }

  static int _matching(String code, int open) {
    final opening = code[open];
    final closing = switch (opening) {
      '(' => ')',
      '{' => '}',
      _ => ']',
    };
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      if (code[i] == opening) depth++;
      if (code[i] == closing && --depth == 0) return i;
    }
    return -1;
  }

  static int _matchingBack(String code, int close) {
    var depth = 0;
    for (var i = close; i >= 0; i--) {
      if (code[i] == ')') depth++;
      if (code[i] == '(' && --depth == 0) return i;
    }
    return -1;
  }

  /// How many brackets are open at [offset] of [text].
  static int _depthAt(String text, int offset) {
    var depth = 0;
    for (var i = 0; i < offset; i++) {
      if ('([{'.contains(text[i])) depth++;
      if (')]}'.contains(text[i])) depth--;
    }
    return depth;
  }

  static int _lineOf(String code, int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;
}
