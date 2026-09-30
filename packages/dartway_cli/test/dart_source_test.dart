import 'package:dartway_cli/src/checker/dw_dart_source.dart';
import 'package:test/test.dart';

/// The one scanner every checker detector reads Dart source through: these
/// are its edge cases, held in one place.
void main() {
  /// Every blanking keeps the source's length and its newlines.
  void expectInPlace(String source, String code) {
    expect(code.length, source.length);
    for (var i = 0; i < source.length; i++) {
      if (source[i] == '\n') expect(code[i], '\n', reason: 'newline at $i');
    }
  }

  String blank(
    String source, {
    bool interpolationsAsCode = false,
    bool keepWordsAndPaths = false,
  }) {
    final code = DwDartSource(
      source,
      interpolationsAsCode: interpolationsAsCode,
      keepWordsAndPaths: keepWordsAndPaths,
    ).code;
    expectInPlace(source, code);
    return code;
  }

  group('comments', () {
    test('a line comment is blanked up to its newline', () {
      expect(blank('a(); // b()\nc();'), 'a();       \nc();');
    });

    test('a doc comment is a line comment', () {
      expect(blank('/// Foo()\nclass A {}'), '         \nclass A {}');
    });

    test('block comments nest', () {
      const source = 'a /* b /* c */ d() */ e();';
      expect(blank(source), 'a${' ' * 21}e();');
    });

    test('a block comment keeps its newlines', () {
      expect(blank('/* a\nb */ c'), '    \n     c');
    });

    test('an unterminated block comment runs to the end', () {
      expect(blank('a /* b\nc'), 'a     \n ');
    });

    test('`//` inside a string is not a comment', () {
      const source = "final u = 'http://x'; f();";
      expect(blank(source), "final u = '        '; f();");
      expect(DwDartSource(source).lineCommentStarts, isEmpty);
    });

    test('a quote inside a comment opens no string', () {
      expect(blank("// don't\nf('x');"), "        \nf(' ');");
    });

    test('line comment starts are recorded, not ones in strings or block '
        'comments', () {
      const source = "a(); // one\n/* // two */ '// three' // four";
      final starts = DwDartSource(source).lineCommentStarts;
      expect(starts, {source.indexOf('// one'), source.indexOf('// four')});
    });
  });

  group('strings', () {
    test('contents are blanked, the quotes stay', () {
      expect(blank("f('a(b', \"c]\");"), "f('   ', \"  \");");
    });

    test('an escaped quote does not end a string', () {
      expect(blank(r"f('a\'b'); g();"), "f('    '); g();");
    });

    test('a raw string has no escapes: its backslash ends nothing', () {
      expect(blank(r"f(r'\'); g('x');"), "f(r' '); g(' ');");
    });

    test('an `r` ending a name does not make a string raw', () {
      // `bar` is not a prefix: the backslash still escapes the quote.
      final literal = DwDartSource(r"bar'\''").literals.single;
      expect(literal.raw, isFalse);
      expect(literal.text, r"\'");
    });

    test('triple quotes of both kinds span lines and hold single quotes', () {
      const source = "f('''a\n'b' \"c\"\n'''); g(\"\"\"d\n\"e\"\n\"\"\"); h();";
      final code = blank(source);
      expect(code, isNot(contains(RegExp('[a-e]'))));
      expect(code, contains('h();'));
      expect(code, contains("'''"));
      expect(code, contains('"""'));
    });

    test('a raw triple-quoted string', () {
      const source = "a(r'''\\'''); b();";
      expect(blank(source), "a(r''' '''); b();");
    });

    test('a one-quote string left open ends with its line', () {
      expect(blank("f('abc\ng();"), "f('   \ng();");
      expect(DwDartSource("f('abc\ng();").literals.single.closed, isFalse);
    });

    test('an unterminated triple-quoted string runs to the end', () {
      expect(blank("f('''a\nb"), "f(''' \n ");
    });

    test('adjacent literals are two literals', () {
      final literals = DwDartSource("f('a' 'b');").literals;
      expect([for (final l in literals) l.text], ['a', 'b']);
    });

    test('raw and triple-quoted strings are blanked, newlines kept', () {
      const source = "a(r'\\'); b('''x\n'y' \"z\"\n'''); c();";
      final code = blank(source);
      expect(code, isNot(contains('x')));
      expect(code, contains('c()'));
      expect('\n'.allMatches(code).length, 2);
    });
  });

  group('interpolation', () {
    test('a nested interpolation with a brace and quotes does not end the '
        'string early', () {
      const source =
          r'''final s = 'a ${m({'k': "}"}['k'])} DwServerFeature(';'''
          '\nfinal t = DwServerFeature(\'x\');';
      final code = blank(source);
      expect(RegExp(r'DwServerFeature\(').allMatches(code), hasLength(1));
      expect(code, contains('final t ='));
    });

    test('by default an interpolation is blanked with its string', () {
      const source = r"final a = 'x ${b('y')} z'; // c";
      final code = blank(source);
      expect(code, isNot(contains('b')));
      expect(code, isNot(contains('y')));
      expect(code, isNot(contains('//')));
      expect(code, startsWith("final a = '"));
    });

    test(r'as code: `${…}` stays, its own strings and comments blanked', () {
      const source = r"f('a ${g('b', /* c */ 1)} d');";
      expect(
        blank(source, interpolationsAsCode: true),
        r"f('  ${g(' ',         1)}  ');",
      );
    });

    test(r'as code: `$name` stays, the text after it does not', () {
      const source = r"f('$now.x $_y z');";
      expect(blank(source, interpolationsAsCode: true), r"f('$now   $_y  ');");
    });

    test(r'`$` before a non-name is text', () {
      const source = r"f('$ 5 $1');";
      expect(blank(source, interpolationsAsCode: true), "f('      ');");
    });

    test('a raw string has no interpolation', () {
      const source = r"f(r'${a('b')}');";
      expect(blank(source, interpolationsAsCode: true), "f(r'    'b'  ');");
      expect(DwDartSource(source).literals, hasLength(2));
    });

    test('an interpolation inside a triple-quoted string, across lines', () {
      const source = "f('''a \${g(\n'}'\n)} b''');";
      final code = blank(source, interpolationsAsCode: true);
      expect(code, "f('''  \${g(\n' '\n)}  ''');");
    });

    test(r'an escaped `\$` does not interpolate', () {
      const source = r"f('\${a(b)}'); g();";
      expect(blank(source, interpolationsAsCode: true), "f('        '); g();");
      expect(DwDartSource(source).literals.single.interpolations, isEmpty);
    });

    test(r'`$name` in a raw string is text', () {
      const source = r"f(r'$now');";
      expect(blank(source, interpolationsAsCode: true), "f(r'    ');");
      expect(DwDartSource(source).literals.single.interpolations, isEmpty);
    });

    test(r'a `${` left open at the end of the source', () {
      const source = r"f('${a(";
      final literal = DwDartSource(source).literals.single;
      expect(literal.closed, isFalse);
      expect(literal.end, source.length);
      expect(blank(source, interpolationsAsCode: true), source);
      expect(blank(source), "f('    ");
    });

    test(r'a `//` comment inside `${…}` is recorded and blanked', () {
      const source = "f('''\${a( // b\n)}''');";
      final scanned = DwDartSource(source, interpolationsAsCode: true);
      expect(scanned.lineCommentStarts, {source.indexOf('//')});
      expect(scanned.code, "f('''\${a(     \n)}''');");
    });

    test('the interpolations are recorded as spans of the source', () {
      const source = r"f('a ${b} $c d');";
      final literal = DwDartSource(source).literals.single;
      expect(
        [for (final (s, e) in literal.interpolations) source.substring(s, e)],
        [r'${b}', r'$c'],
      );
    });

    test('strings inside an interpolation are not literals of the source', () {
      final literals = DwDartSource(r"f('${g('x')}'); h('y');").literals;
      expect([for (final l in literals) l.text], [r"${g('x')}", 'y']);
    });
  });

  group('literals', () {
    test('span, contents and text as written', () {
      const source = r"a(r'x\n', '''y''');";
      final [raw, triple] = DwDartSource(source).literals;
      expect(source.substring(raw.start, raw.end), r"r'x\n'");
      expect(raw.text, r'x\n');
      expect(raw.raw, isTrue);
      expect(source.substring(triple.start, triple.end), "'''y'''");
      expect(source.substring(triple.contentStart, triple.contentEnd), 'y');
      expect(triple.closed, isTrue);
    });

    test('lineOf counts from 1', () {
      final source = DwDartSource('a\nb\nc');
      expect(source.lineOf(0), 1);
      expect(source.lineOf(4), 3);
    });
  });

  group('words and paths', () {
    test('a word, a path, a package URI and an empty string stay', () {
      const source =
          "import 'package:http/http.dart'; f(env['PORT'], '', 'a/b.c');";
      expect(blank(source, keepWordsAndPaths: true), source);
    });

    test('prose is blanked like any string', () {
      expect(
        blank("f('two words', 'a\$b');", keepWordsAndPaths: true),
        "f('         ', '   ');",
      );
    });

    test('with interpolations as code: a kept word, a blanked sentence, '
        'and the interpolation inside it', () {
      const source = r"f('PORT', 'on ${env['PORT']} now', 'a b');";
      expect(
        blank(source, interpolationsAsCode: true, keepWordsAndPaths: true),
        r"f('PORT', '   ${env['PORT']}    ', '   ');",
      );
    });

    test('comments still go', () {
      expect(
        blank("// 'PORT'\nf('PORT');", keepWordsAndPaths: true),
        "         \nf('PORT');",
      );
    });
  });
}
