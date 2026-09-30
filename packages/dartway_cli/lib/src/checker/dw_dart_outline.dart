/// A reading of Dart source good enough to say what a file *declares*, without
/// the analyzer: the CLI does not depend on it, and what the checks ask is
/// narrow — which framework types a file constructs, and which named functions
/// it declares at the top level or in a type's body.
///
/// It relies on what `dart format` guarantees and nothing more: brackets
/// balance once comments and strings are blanked, and a declaration's name and
/// its opening parenthesis share a line.
library;

import 'dw_dart_source.dart';

/// A named function, method or getter declared at the top level or directly
/// in the body of a class, mixin, enum or extension.
final class DwDeclaredFunction {
  const DwDeclaredFunction({
    required this.name,
    required this.returnType,
    required this.parameters,
    required this.bodyStart,
    required this.bodyEnd,
    required this.offset,
    this.enclosingType,
    this.extendedType,
    this.isField = false,
  });

  final String name;

  /// A field holding a closure — `static final announce = (ctx, row) {…}` —
  /// rather than a function. The same declaration to every rule: rewriting a
  /// function as a field does not move it anywhere. [returnType] is then the
  /// field's type as written, empty when it is inferred.
  final bool isField;

  /// As written before the name, modifiers such as `static` included.
  final String returnType;

  /// Between the parentheses; empty for a getter.
  final String parameters;

  /// The body's span in the blanked source: from `{` or `=>` to its end.
  final int bodyStart;
  final int bodyEnd;

  /// Where the declaration starts, for the line number.
  final int offset;

  /// The class, mixin or enum it is declared in, if any.
  final String? enclosingType;

  /// For an extension member: the type after `on`.
  final String? extendedType;
}

/// What a blanked Dart file declares, and where its brackets close.
final class DwDartOutline {
  DwDartOutline(String source) : code = DwDartSource(source).code {
    _matchBrackets();
    _collectDeclarations();
  }

  /// The source with comments and strings blanked.
  final String code;

  final Map<int, int> _closing = {};

  /// The bracket each bracket opens inside, if any.
  final Map<int, int> _parent = {};
  final List<DwDeclaredFunction> functions = [];

  /// 1-based line of [offset].
  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset.clamp(0, code.length))).length +
      1;

  static const _open = {'(': ')', '[': ']', '{': '}'};

  void _matchBrackets() {
    final stack = <int>[];
    for (var i = 0; i < code.length; i++) {
      final c = code[i];
      if (_open.containsKey(c)) {
        if (stack.isNotEmpty) _parent[i] = stack.last;
        stack.add(i);
      } else if (c == ')' || c == ']' || c == '}') {
        if (stack.isEmpty) continue;
        _closing[stack.removeLast()] = i;
      }
    }
  }

  /// The index of the bracket closing the one at [open], or the end of the
  /// code when it never closes.
  int closeOf(int open) => _closing[open] ?? code.length;

  static final _typeHeader = RegExp(
    r'\b(?:class|mixin|enum)\s+(\w+)|\bextension\s+(?:type\s+)?(\w+)?[^{]*?\bon\s+([\w.]+)',
  );

  static final _declarationHeader = RegExp(
    r'(?:@[\w.]+(?:\([^\n]*?\))?\s+)*'
    r'(?:(?:static|external|abstract|late)\s+)*'
    r'(?:([^;=\n]*?[\w>?)\]])\s+)?'
    r'(get\s+)?'
    r'([A-Za-z_$][\w$]*)'
    r'\s*(?:<[^;=\n()]*?>)?\s*'
    r'(\()?',
  );

  static final _closureField = RegExp(
    r'(?:@[\w.]+(?:\([^\n]*?\))?\s+)*'
    r'(?:(?:static|late|final|var|const)\s+)*'
    r'(?:([^;=\n]*?[\w>?)\]])\s+)?'
    r'([A-Za-z_$][\w$]*)\s*=\s*\(',
  );

  static const _notNames = {
    'if',
    'for',
    'while',
    'switch',
    'return',
    'await',
    'throw',
    'new',
    'const',
    'final',
    'var',
    'late',
    'class',
    'enum',
    'mixin',
    'extension',
    'typedef',
    'import',
    'export',
    'part',
    'library',
    'factory',
    'operator',
    'get',
    'set',
    'static',
    'abstract',
    'sealed',
    'base',
    'interface',
  };

  void _collectDeclarations() {
    // Top-level braces and whether each opens a type's body.
    var i = 0;
    while (i < code.length) {
      final c = code[i];
      if (c == '{') {
        final header = _headerBefore(i);
        final type = _typeHeader.firstMatch(header);
        final end = closeOf(i);
        if (type != null) {
          _collectIn(
            i + 1,
            end,
            enclosingType: type.group(1),
            extendedType: type.group(3),
          );
        }
        i = end + 1;
        continue;
      }
      if (i == 0 || code[i - 1] == '\n') {
        final declared = _declarationAt(i);
        if (declared != null) {
          functions.add(declared);
          i = declared.bodyEnd;
          continue;
        }
      }
      if (c == '(' || c == '[') {
        i = closeOf(i) + 1;
        continue;
      }
      i++;
    }
  }

  /// Declarations directly inside a type body spanning [from]..[to].
  void _collectIn(
    int from,
    int to, {
    String? enclosingType,
    String? extendedType,
  }) {
    var i = from;
    while (i < to) {
      final c = code[i];
      if (code[i - 1] == '\n') {
        final declared = _declarationAt(
          i,
          enclosingType: enclosingType,
          extendedType: extendedType,
        );
        if (declared != null) {
          functions.add(declared);
          i = declared.bodyEnd;
          continue;
        }
      }
      if (c == '{' || c == '(' || c == '[') {
        i = closeOf(i) + 1;
        continue;
      }
      i++;
    }
  }

  /// The text between the previous top-level boundary and [brace].
  String _headerBefore(int brace) {
    var k = brace - 1;
    while (k >= 0 && code[k] != ';' && code[k] != '}') {
      k--;
    }
    return code.substring(k + 1, brace);
  }

  DwDeclaredFunction? _declarationAt(
    int lineStart, {
    String? enclosingType,
    String? extendedType,
  }) {
    var j = lineStart;
    while (j < code.length && (code[j] == ' ' || code[j] == '\t')) {
      j++;
    }
    final field = _closureField.matchAsPrefix(code, j);
    if (field != null && !_notNames.contains(field.group(2))) {
      final open = field.end - 1;
      final body = _bodyAfter(closeOf(open) + 1);
      if (body != null) {
        return DwDeclaredFunction(
          name: field.group(2)!,
          returnType: (field.group(1) ?? '')
              .replaceAll(
                RegExp(r'^(?:(?:static|late|final|var|const)\s+)+'),
                '',
              )
              .trim(),
          parameters: code.substring(open + 1, closeOf(open)),
          bodyStart: body.$1,
          bodyEnd: body.$2,
          offset: j,
          enclosingType: enclosingType,
          extendedType: extendedType,
          isField: true,
        );
      }
    }
    final match = _declarationHeader.matchAsPrefix(code, j);
    if (match == null) return null;
    final name = match.group(3)!;
    if (_notNames.contains(name)) return null;
    final isGetter = match.group(2) != null;
    final hasParens = match.group(4) != null;
    if (isGetter == hasParens) return null;

    var k = match.end;
    var parameters = '';
    if (hasParens) {
      final close = closeOf(match.end - 1);
      parameters = code.substring(match.end, close);
      k = close + 1;
    }
    final body = _bodyAfter(k);
    if (body == null) return null;
    return DwDeclaredFunction(
      name: name,
      returnType: (match.group(1) ?? '').trim(),
      parameters: parameters,
      bodyStart: body.$1,
      bodyEnd: body.$2,
      offset: j,
      enclosingType: enclosingType,
      extendedType: extendedType,
    );
  }

  /// The body starting at [k] after an optional `async`/`async*`/`sync*`:
  /// `{…}` or `=> …`, as its start and end; null when none starts there.
  (int, int)? _bodyAfter(int k) {
    k = _skipSpace(k);
    for (final modifier in const ['async*', 'sync*', 'async']) {
      if (code.startsWith(modifier, k)) {
        k = _skipSpace(k + modifier.length);
        break;
      }
    }
    if (k < code.length && code[k] == '{') return (k, closeOf(k) + 1);
    if (code.startsWith('=>', k)) return (k, _expressionEnd(k + 2));
    return null;
  }

  int _skipSpace(int k) {
    while (k < code.length && code[k].trim().isEmpty) {
      k++;
    }
    return k;
  }

  /// Past the end of the expression starting at [from]: the first `;`, `,`
  /// or unmatched closing bracket outside any nested brackets.
  int _expressionEnd(int from) {
    var k = from;
    while (k < code.length) {
      final c = code[k];
      if (c == '(' || c == '[' || c == '{') {
        k = closeOf(k) + 1;
        continue;
      }
      if (c == ';' || c == ',' || c == ')' || c == ']' || c == '}') return k;
      k++;
    }
    return code.length;
  }

  /// The offsets in [function]'s body where [pattern] matches — its own
  /// code and every closure it runs, except a hook it hands to a
  /// constructor by name: `DwAuthConfig(onAccountCreated: (ctx, …) {…})`.
  ///
  /// A publish inside such a hook belongs to the hook, not to the method that
  /// builds the config; a publish inside `rows.forEach((r) => …)` or
  /// `db.transaction((tx) async {…})` is the helper's own.
  List<int> ownMatches(DwDeclaredFunction function, RegExp pattern) {
    final start = function.bodyStart;
    final end = function.bodyEnd;
    final hooks = <(int, int)>[];
    for (var k = start; k < end; k++) {
      if (code[k] != '(') continue;
      final close = closeOf(k);
      if (close >= end) continue;
      if (!_isClosureParameters(k) || !_isConstructorHook(k)) continue;
      final body = _bodyAfter(close + 1);
      if (body != null && body.$1 < end) hooks.add(body);
    }
    final text = code.substring(start, end);
    return [
      for (final match in pattern.allMatches(text))
        if (!hooks.any(
          (range) =>
              start + match.start > range.$1 && start + match.start < range.$2,
        ))
          start + match.start,
    ];
  }

  /// Whether the closure whose parameters open at [open] is a named argument
  /// (`name: (…) …`) of a call whose callee starts with a capital — a
  /// constructor or a type's static, `DwAuthConfig(` or `DwChannelRule.keyed(`.
  bool _isConstructorHook(int open) {
    var k = open - 1;
    while (k >= 0 && code[k].trim().isEmpty) {
      k--;
    }
    if (k < 0 || code[k] != ':') return false;
    final call = _parent[open];
    if (call == null || code[call] != '(') return false;
    var c = call - 1;
    while (c >= 0 && code[c].trim().isEmpty) {
      c--;
    }
    // Past type arguments: `DwChannelRule.keyed<int>(`.
    if (c >= 0 && code[c] == '>') {
      var depth = 0;
      while (c >= 0) {
        if (code[c] == '>') depth++;
        if (code[c] == '<') depth--;
        c--;
        if (depth == 0) break;
      }
    }
    var from = c;
    while (from >= 0 && RegExp(r'[\w$.]').hasMatch(code[from])) {
      from--;
    }
    final callee = code.substring(from + 1, c + 1);
    return RegExp(r'^[A-Z]').hasMatch(callee);
  }

  /// Whether the `(` at [open] opens a closure's parameters: what stands
  /// before it is punctuation, not a name — `if (`, `catch (`, `helper(` and
  /// `foo<T>(` are not closures.
  bool _isClosureParameters(int open) {
    var k = open - 1;
    while (k >= 0 && code[k].trim().isEmpty) {
      k--;
    }
    if (k < 0) return true;
    final c = code[k];
    return !RegExp(r'[\w$>)\]?!]').hasMatch(c);
  }
}
