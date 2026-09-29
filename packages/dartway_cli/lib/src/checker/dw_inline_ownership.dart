import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';

/// Ownership checked inline after `DwAccessRule.signedIn`
/// ([DwCheckType.inlineOwnershipCheck], dartway/dartway#387).
///
/// In a server file named `*_handlers.dart`, a handler whose rule is
/// `DwAccessRule.signedIn` and which compares an owner field of a row with
/// the caller and refuses `dw.notFound` or `dw.forbidden` — in its own body,
/// or in a helper of the same file it calls — is the check
/// `DwAccessRule.resource` makes once. A heuristic, so a warning, and a
/// conservative one:
///
/// - the comparison is `!=` between a field whose name ends in `Id` and names
///   an owner (`owner`, `author`, `user`, `profile`, `account`, `sender`,
///   `recipient`, `creator`, `createdBy`, `member`) and an expression that
///   names the caller (`me`, `my…`, `caller…`, `current…`, `profile`,
///   `accountId`);
/// - it is the condition of an `if` whose branch refuses `notFound` or
///   `forbidden` — or, in a `single` handler, answers `return null`, which the
///   framework refuses `notFound`;
/// - a helper counts only when a `signedIn` handler of the same file calls it.
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
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_handlers.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final shown = p.relative(file.path, from: server.parent.path);
      for (final site in inlineOwnershipIn(file.readAsStringSync())) {
        _findings.add(
          '${site.helper == null ? 'a signedIn handler' : '`${site.helper}`, called by a signedIn handler,'} '
          'checks ownership inline — $shown:${site.line}; guard the handler '
          'with DwAccessRule.resource and read the row as ctx.accessed',
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

  /// The inline ownership checks of one handlers file: the line of each, and
  /// the helper it sits in when it is not in a handler's own body.
  static List<({int line, String? helper})> inlineOwnershipIn(String content) {
    final code = _withoutCommentsAndStrings(content);
    final handlers = _handlers(code);
    final signedIn = handlers.where((h) => h.signedIn).toList();
    if (signedIn.isEmpty) return const [];

    final sites = <({int line, String? helper})>[];
    for (final (:start, :end, :refusesByNull) in _ownerRefusals(code)) {
      final handler = handlers
          .where((h) => h.start <= start && end <= h.end)
          .firstOrNull;
      if (handler != null) {
        final nullCounts = handler.kind == 'single';
        if (handler.signedIn && (!refusesByNull || nullCounts)) {
          sites.add((line: _lineOf(code, start), helper: null));
        }
        continue;
      }
      if (refusesByNull) continue;
      final helper = _enclosingFunction(code, start);
      if (helper == null) continue;
      final call = RegExp('\\b${RegExp.escape(helper)}\\s*(<[^>]*>)?\\s*\\(');
      final called = signedIn.any(
        (h) => call.hasMatch(code.substring(h.start, h.end)),
      );
      if (called) sites.add((line: _lineOf(code, start), helper: helper));
    }
    return sites;
  }

  static final _handlerStart = RegExp(
    r'\bDwCallHandler\s*\.\s*(single|maybe|list|page|table|window|command)\b',
  );
  static final _signedIn = RegExp(
    r'\baccess\s*:\s*DwAccessRule\s*\.\s*signedIn\b',
  );

  static List<({int start, int end, String kind, bool signedIn})> _handlers(
    String code,
  ) {
    final found = <({int start, int end, String kind, bool signedIn})>[];
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
      final rule = _signedIn.firstMatch(body);
      found.add((
        start: open,
        end: close,
        kind: match.group(1)!,
        signedIn: rule != null && _depthAt(body, rule.start) == 1,
      ));
    }
    return found;
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

  /// [content] with comments removed and string contents blanked, newlines
  /// kept so a finding is reported on its own line.
  static String _withoutCommentsAndStrings(String content) {
    final out = StringBuffer();
    var i = 0;
    void newlinesOf(String skipped) =>
        out.write('\n' * '\n'.allMatches(skipped).length);

    while (i < content.length) {
      if (content.startsWith('//', i)) {
        final end = content.indexOf('\n', i);
        i = end < 0 ? content.length : end;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final close = content.indexOf('*/', i + 2);
        final end = close < 0 ? content.length : close + 2;
        newlinesOf(content.substring(i, end));
        i = end;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        final raw = i > 0 && content[i - 1] == 'r';
        final delimiter = content.startsWith(char * 3, i) ? char * 3 : char;
        var j = i + delimiter.length;
        while (j < content.length && !content.startsWith(delimiter, j)) {
          j += !raw && content[j] == r'\' ? 2 : 1;
        }
        final end = j + delimiter.length > content.length
            ? content.length
            : j + delimiter.length;
        out.write('""');
        newlinesOf(content.substring(i, end));
        i = end;
        continue;
      }
      out.write(char);
      i++;
    }
    return out.toString();
  }
}
