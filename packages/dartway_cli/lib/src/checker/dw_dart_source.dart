/// The one reading of Dart source every checker detector starts from: which
/// characters are code, and which are comments and string literals.
///
/// The checks read source with regular expressions, not with the analyzer, so
/// each of them first needs the text with comments and strings out of the way
/// — a `DateTime.now()` in a doc comment, a bracket in a string, a `//` inside
/// a URL are not code. This is the one scanner that says so, and the one set
/// of fixtures (`test/dart_source_test.dart`) that holds its edge cases.
library;

/// A Dart source read into code, comments and string literals.
///
/// [code] is [content] with every comment and every string literal's contents
/// replaced by spaces: the same length, the same newlines, so an offset or a
/// line number found in [code] points into [content]. A literal's delimiters
/// stay — `'…'`, `"""…"""`, and the `r` of a raw string — so where a string
/// stood is still visible, and an `import` is still followed by a quote.
///
/// Comments nest (`/* /* */ */`); a `//` inside a string is not a comment; a
/// quote inside `${…}` does not end the string around it; a one-quote literal
/// left open ends with its line.
final class DwDartSource {
  /// Reads [content].
  ///
  /// With [interpolationsAsCode] the interpolations of a literal — `${…}` and
  /// `$name` — are left in [code] as written, with their own comments and
  /// strings blanked: `'${DateTime.now()}'` reads the clock. Without it they
  /// are blanked with the string around them.
  ///
  /// With [keepWordsAndPaths] a literal holding one word or a path —
  /// `'PORT'`, `'package:http/http.dart'`, `''` — stays in [code] as written:
  /// what an import names and a map read by a literal key are strings. Every
  /// other literal is blanked as usual.
  DwDartSource(
    this.content, {
    this.interpolationsAsCode = false,
    this.keepWordsAndPaths = false,
  }) : _out = List.of(content.codeUnits) {
    _scanCode(0, nested: false);
    code = String.fromCharCodes(_out);
  }

  final String content;
  final bool interpolationsAsCode;
  final bool keepWordsAndPaths;

  /// [content] with comments and string contents blanked (see the class).
  late final String code;

  /// Every string literal outside an interpolation, in source order.
  final List<DwStringLiteral> literals = [];

  /// Where each `//` comment starts — not one inside a string or a block
  /// comment.
  final Set<int> lineCommentStarts = {};

  final List<int> _out;

  /// 1-based line of [offset].
  int lineOf(int offset) =>
      '\n'
          .allMatches(content.substring(0, offset.clamp(0, content.length)))
          .length +
      1;

  static const _slash = 0x2F;
  static const _star = 0x2A;
  static const _newline = 0x0A;
  static const _space = 0x20;
  static const _backslash = 0x5C;
  static const _dollar = 0x24;
  static const _braceOpen = 0x7B;
  static const _braceClose = 0x7D;
  static const _single = 0x27;
  static const _double = 0x22;
  static const _r = 0x72;

  static final _wordOrPath = RegExp(r'^[\w:/.\-]*$');
  static final _identifierStart = RegExp(r'[A-Za-z_]');
  static final _identifierPart = RegExp(r'[\w]');
  static final _nameCharacter = RegExp(r'[\w$]');

  int get _length => content.length;

  int _at(int i) => content.codeUnitAt(i);

  void _blank(int from, int to) {
    for (var k = from; k < to && k < _out.length; k++) {
      if (_out[k] != _newline) _out[k] = _space;
    }
  }

  /// Scans code from [from]: to the end of [content], or — [nested], the
  /// code of an interpolation — past the `}` that closes it.
  int _scanCode(int from, {required bool nested}) {
    var depth = 0;
    var i = from;
    while (i < _length) {
      final c = _at(i);
      if (c == _slash && i + 1 < _length) {
        final next = _at(i + 1);
        if (next == _slash) {
          lineCommentStarts.add(i);
          final end = content.indexOf('\n', i);
          final stop = end < 0 ? _length : end;
          _blank(i, stop);
          i = stop;
          continue;
        }
        if (next == _star) {
          final stop = _blockCommentEnd(i);
          _blank(i, stop);
          i = stop;
          continue;
        }
      }
      if (c == _single || c == _double) {
        i = _scanString(i, nested: nested);
        continue;
      }
      if (nested) {
        if (c == _braceOpen) depth++;
        if (c == _braceClose) {
          if (depth == 0) return i + 1;
          depth--;
        }
      }
      i++;
    }
    return _length;
  }

  /// Past the end of the (possibly nested) block comment starting at [start].
  int _blockCommentEnd(int start) {
    var depth = 0;
    var k = start;
    while (k + 1 < _length) {
      if (_at(k) == _slash && _at(k + 1) == _star) {
        depth++;
        k += 2;
        continue;
      }
      if (_at(k) == _star && _at(k + 1) == _slash) {
        k += 2;
        if (--depth == 0) return k;
        continue;
      }
      k++;
    }
    return _length;
  }

  /// Whether the quote at [quote] opens a raw string: an `r` right before it
  /// that is not the end of a name.
  bool _isRaw(int quote) =>
      quote > 0 &&
      _at(quote - 1) == _r &&
      (quote < 2 || !_nameCharacter.hasMatch(content[quote - 2]));

  /// Scans the literal whose opening quote is at [quote] and returns the
  /// offset past it.
  int _scanString(int quote, {required bool nested}) {
    final raw = _isRaw(quote);
    final q = _at(quote);
    final triple =
        quote + 2 < _length && _at(quote + 1) == q && _at(quote + 2) == q;
    final delimiter = triple ? 3 : 1;
    final contentStart = quote + delimiter;
    final interpolations = <(int, int)>[];
    var i = contentStart;
    var closed = false;
    while (i < _length) {
      final c = _at(i);
      if (c == q &&
          (!triple ||
              (i + 2 < _length && _at(i + 1) == q && _at(i + 2) == q))) {
        closed = true;
        break;
      }
      if (!triple && c == _newline) break;
      if (!raw && c == _backslash) {
        i += 2;
        continue;
      }
      if (!raw && c == _dollar && i + 1 < _length) {
        if (_at(i + 1) == _braceOpen) {
          final end = _scanCode(i + 2, nested: true);
          interpolations.add((i, end));
          i = end;
          continue;
        }
        if (_identifierStart.hasMatch(content[i + 1])) {
          var k = i + 2;
          while (k < _length && _identifierPart.hasMatch(content[k])) {
            k++;
          }
          interpolations.add((i, k));
          i = k;
          continue;
        }
      }
      i++;
    }
    final contentEnd = i > _length ? _length : i;
    final end = closed ? contentEnd + delimiter : contentEnd;
    final text = content.substring(contentStart, contentEnd);

    final kept = keepWordsAndPaths && _wordOrPath.hasMatch(text);
    if (!kept) {
      if (interpolationsAsCode) {
        var from = contentStart;
        for (final (start, stop) in interpolations) {
          _blank(from, start);
          from = stop;
        }
        _blank(from, contentEnd);
      } else {
        _blank(contentStart, contentEnd);
      }
    }
    if (!nested) {
      literals.add(
        DwStringLiteral._(
          start: raw ? quote - 1 : quote,
          end: end,
          contentStart: contentStart,
          contentEnd: contentEnd,
          text: text,
          raw: raw,
          closed: closed,
          interpolations: List.unmodifiable(interpolations),
        ),
      );
    }
    return end;
  }
}

/// One string literal of a [DwDartSource], as written.
final class DwStringLiteral {
  const DwStringLiteral._({
    required this.start,
    required this.end,
    required this.contentStart,
    required this.contentEnd,
    required this.text,
    required this.raw,
    required this.closed,
    required this.interpolations,
  });

  /// Where the literal starts — its `r` when raw, else its opening quote —
  /// and where it ends, past the closing quote.
  final int start;
  final int end;

  /// The span between the quotes.
  final int contentStart;
  final int contentEnd;

  /// What is between the quotes, exactly as written: escapes undecoded,
  /// interpolations included.
  final String text;

  final bool raw;

  /// Whether the closing quote was found; a one-quote literal left open ends
  /// with its line, a triple-quoted one with the source.
  final bool closed;

  /// The interpolations — `${…}` and `$name` — as spans of the source.
  final List<(int, int)> interpolations;
}
