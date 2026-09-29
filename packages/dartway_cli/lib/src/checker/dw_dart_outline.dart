/// A reading of Dart source good enough to say what a file *declares*, without
/// the analyzer: the CLI does not depend on it, and what the checks ask is
/// narrow — which framework types a file constructs, and which named functions
/// it declares at the top level or in a type's body.
///
/// It relies on what `dart format` guarantees and nothing more: brackets
/// balance once comments and strings are blanked, and a declaration's name and
/// its opening parenthesis share a line.
library;

/// [source] with every comment and string literal replaced by spaces,
/// newlines kept — so offsets and line numbers still point into the original,
/// and a name inside a comment or a string is not taken for code.
String dwBlankNonCode(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;

  void blank(int from, int to) {
    for (var k = from; k < to; k++) {
      out.write(source[k] == '\n' ? '\n' : ' ');
    }
  }

  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      final start = i;
      while (i < n && source[i] != '\n') {
        i++;
      }
      blank(start, i);
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      final end = dwSkipBlockComment(source, i);
      blank(i, end);
      i = end;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final end = _skipString(source, i, raw: raw);
      blank(i, end);
      i = end;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Past the string literal starting at [start] (its opening quote, after any
/// `r`). Interpolations are skipped as code, so a quote inside `${…}` does not
/// end the string.
int _skipString(String source, int start, {required bool raw}) {
  final n = source.length;
  final quote = source[start];
  final triple =
      start + 2 < n && source[start + 1] == quote && source[start + 2] == quote;
  var k = start + (triple ? 3 : 1);
  while (k < n) {
    final c = source[k];
    if (!raw && c == r'\') {
      k += 2;
      continue;
    }
    if (!raw && c == r'$' && k + 1 < n && source[k + 1] == '{') {
      k = _skipInterpolation(source, k + 2);
      continue;
    }
    if (triple) {
      if (c == quote &&
          k + 2 < n &&
          source[k + 1] == quote &&
          source[k + 2] == quote) {
        return k + 3;
      }
    } else if (c == quote) {
      return k + 1;
    } else if (c == '\n') {
      return k; // an unterminated literal ends with its line
    }
    k++;
  }
  return n;
}

/// Past the `}` that closes the interpolation whose code starts at [start].
int _skipInterpolation(String source, int start) {
  final n = source.length;
  var depth = 0;
  var k = start;
  while (k < n) {
    final c = source[k];
    if (c == '/' && k + 1 < n && source[k + 1] == '/') {
      while (k < n && source[k] != '\n') {
        k++;
      }
      continue;
    }
    if (c == '/' && k + 1 < n && source[k + 1] == '*') {
      k = dwSkipBlockComment(source, k);
      continue;
    }
    if (c == "'" || c == '"') {
      k = _skipString(source, k, raw: k > 0 && source[k - 1] == 'r');
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      if (depth == 0) return k + 1;
      depth--;
    }
    k++;
  }
  return n;
}

/// Past the end of the (possibly nested) block comment starting at [start].
int dwSkipBlockComment(String text, int start) {
  var depth = 0;
  var k = start;
  while (k < text.length) {
    if (text.startsWith('/*', k)) {
      depth++;
      k += 2;
      continue;
    }
    if (text.startsWith('*/', k)) {
      depth--;
      k += 2;
      if (depth == 0) return k;
      continue;
    }
    k++;
  }
  return text.length;
}

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
  });

  final String name;

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
  DwDartOutline(String source) : code = dwBlankNonCode(source) {
    _matchBrackets();
    _collectDeclarations();
  }

  /// The source with comments and strings blanked.
  final String code;

  final Map<int, int> _closing = {};
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
      if (c == '(' || c == '[') {
        i = closeOf(i) + 1;
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
      if (c == '{' || c == '(' || c == '[') {
        i = closeOf(i) + 1;
        continue;
      }
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
    k = _skipSpace(k);
    for (final modifier in const ['async*', 'sync*', 'async']) {
      if (code.startsWith(modifier, k)) {
        k = _skipSpace(k + modifier.length);
        break;
      }
    }
    final int bodyEnd;
    if (k < code.length && code[k] == '{') {
      bodyEnd = closeOf(k) + 1;
    } else if (code.startsWith('=>', k)) {
      bodyEnd = _expressionEnd(k + 2);
    } else {
      return null;
    }
    return DwDeclaredFunction(
      name: name,
      returnType: (match.group(1) ?? '').trim(),
      parameters: parameters,
      bodyStart: k,
      bodyEnd: bodyEnd,
      offset: j,
      enclosingType: enclosingType,
      extendedType: extendedType,
    );
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

  /// The offsets in [function]'s body where [pattern] matches outside any
  /// closure the body passes on — a callback's `(…) {…}` or `(…) => …`.
  ///
  /// A publish inside a hook handed to a config belongs to the hook, not to
  /// the method that builds the config.
  List<int> ownMatches(DwDeclaredFunction function, RegExp pattern) {
    final start = function.bodyStart;
    final end = function.bodyEnd;
    final closures = <(int, int)>[];
    for (var k = start; k < end; k++) {
      if (code[k] != '(') continue;
      final close = closeOf(k);
      if (close >= end) continue;
      if (!_isClosureParameters(k)) continue;
      var after = _skipSpace(close + 1);
      for (final modifier in const ['async*', 'sync*', 'async']) {
        if (code.startsWith(modifier, after)) {
          after = _skipSpace(after + modifier.length);
          break;
        }
      }
      if (after < end && code[after] == '{') {
        closures.add((after, closeOf(after)));
      } else if (code.startsWith('=>', after)) {
        closures.add((after, _expressionEnd(after + 2)));
      }
    }
    final body = code.substring(start, end);
    return [
      for (final match in pattern.allMatches(body))
        if (!closures.any(
          (range) =>
              start + match.start > range.$1 && start + match.start < range.$2,
        ))
          start + match.start,
    ];
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
