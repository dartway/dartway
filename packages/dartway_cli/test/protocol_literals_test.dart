import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A protocol bump (`dwProtocolVersion` in `dw_http_contract.dart`) is
/// invisible to a hand-written header or query literal: nothing refuses to
/// compile. #305 bumped it 1 → 2, and two tests kept `'dw-protocol': '1'` /
/// `?protocol=1` for months (#339): one failed for the wrong reason (every
/// DTO call refused before the behavior it claimed to test), the other
/// *passed* for the wrong reason — a live upgrade was refused as
/// incompatible before the ping path it named itself for was ever reached.
/// Fixed by #345. This test catches the class mechanically, in the spirit
/// of `docs_identifiers_test.dart`.
///
/// ## Scope
///
/// Every `test/` directory under `packages/`, `tool/`, `template/` and
/// `example/` — recursively, so a nested one (`dartway_lints/example/test`)
/// or a non-Dart one (an Android `src/test`, filtered by extension) is
/// still handled correctly. That is exactly where a hand-rolled HTTP
/// request gets built or a captured one gets read back; `lib/` is not
/// scanned; every call site there already resolves through
/// `DwHttpContract` and a rename breaks the build instead of drifting
/// silently, which is the whole difference between production code and a
/// test the compiler cannot check. `dw_http_contract.dart` itself, which
/// declares the literal wire text these constants stand for, lives under
/// `lib/` and is therefore already out of reach — read below as the source
/// of truth, never scanned as a target.
///
/// ## What counts as a violation
///
/// Only *writing* a header name as a literal — the shape that put the wrong
/// value on the wire in both #339 sites:
///
/// - a map-literal entry (`'dw-protocol': …`) or a subscript assignment
///   (`headers['dw-protocol'] = …`) keyed by one of the three header names
///   this test polices, instead of `DwHttpContract.protocolHeader` /
///   `.appVersionHeader` / `.contractVersionHeader`;
/// - a `?protocol=<digit>` query literal instead of interpolating
///   `dwProtocolVersion`.
///
/// *Reading* a header back (`headers['dw-protocol']`, `.value('dw-protocol')`)
/// is deliberately not flagged: a renamed header there fails the assertion
/// immediately and loudly — the opposite of the silent-pass bug this test
/// exists for — and several tests do it legitimately (`calls_test.dart`,
/// `contract_version_test.dart`, `real_transport_test.dart`).
///
/// ## What is excluded, and why
///
/// `dartway_core_shared/test/goldens/wire_golden.dart` is generated
/// (`DO NOT EDIT`) and pins the *entire* wire format byte-for-byte,
/// including every header and query name, as JSON list values — a golden
/// existing on purpose to catch drift, not a hand-written call site. It
/// happens not to trip the shapes above today (its header names sit in a
/// JSON array, not a map key or an assignment), but it is excluded by name
/// rather than left to that accident: narrowing the rule to dodge a golden
/// is how the rule stops noticing a real one beside it.
void main() {
  final root = _repositoryRoot();

  final contractSource = File(
    p.join(
      root.path,
      'packages',
      'dartway_core_shared',
      'lib',
      'src',
      'protocol',
      'dw_http_contract.dart',
    ),
  ).readAsStringSync();

  // The three header names this test polices, read from their own
  // declaration rather than retyped here — a future rename needs no
  // matching edit in this file. Every other header `DwHttpContract` names
  // (`Authorization`, `Dw-Idempotency-Key`, …) does not carry a version and
  // is not this test's concern.
  final constantFor = <String, String>{};
  for (final match in RegExp(
    r"static const String (protocolHeader|appVersionHeader|contractVersionHeader) = '([^']+)';",
  ).allMatches(contractSource)) {
    constantFor[match.group(2)!.toLowerCase()] =
        'DwHttpContract.${match.group(1)}';
  }
  final liveProtocolParameter = RegExp(
    r"static const String liveProtocolParameter = '([^']+)';",
  ).firstMatch(contractSource)!.group(1)!;

  test('dw_http_contract.dart still declares the three version headers', () {
    // A guard on the guard: if this fails, the file moved or was reshaped
    // and every finding below would silently be about nothing.
    expect(
      constantFor.keys,
      containsAll(['dw-protocol', 'dw-app-version', 'dw-contract-version']),
      reason:
          'dw_http_contract.dart moved or was reshaped; point this test '
          'at it again',
    );
  });

  final headerNamePattern = constantFor.keys.map(RegExp.escape).join('|');
  final headerAsMapKey = RegExp(
    "(['\"])(?:$headerNamePattern)\\1\\s*:",
    caseSensitive: false,
  );
  final headerAsSubscriptAssignment = RegExp(
    "\\[\\s*(['\"])(?:$headerNamePattern)\\1\\s*\\]\\s*=(?!=)",
    caseSensitive: false,
  );
  final headerNameIn = RegExp(
    "(['\"])((?:$headerNamePattern))\\1",
    caseSensitive: false,
  );
  final protocolQueryDigit = RegExp(
    '[?&]${RegExp.escape(liveProtocolParameter)}=\\d',
  );

  final excluded = {
    p.normalize(
      p.join(
        root.path,
        'packages',
        'dartway_core_shared',
        'test',
        'goldens',
        'wire_golden.dart',
      ),
    ),
  };

  final headerFindings = <String>[];
  final queryFindings = <String>[];

  for (final testDir in _testDirectoriesUnder(root)) {
    final files =
        testDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = p.normalize(file.absolute.path);
      if (excluded.contains(path)) continue;
      final where = p.relative(path, from: root.path).replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A comment (most of all this file's own doc comment, which quotes
        // both stale shapes as prose) is not code that puts anything on the
        // wire.
        if (line.trimLeft().startsWith('//')) continue;
        for (final regex in [headerAsMapKey, headerAsSubscriptAssignment]) {
          for (final match in regex.allMatches(line)) {
            final name = headerNameIn.firstMatch(match.group(0)!)!.group(2)!;
            headerFindings.add(
              '$where:${i + 1} — \'$name\' written as a literal header '
              'name; use ${constantFor[name.toLowerCase()]}',
            );
          }
        }
        for (final match in protocolQueryDigit.allMatches(line)) {
          queryFindings.add(
            '$where:${i + 1} — \'${match.group(0)}\' as a literal query; '
            'interpolate dwProtocolVersion instead of the digit',
          );
        }
      }
    }
  }

  test('no protocol / contract-version / app-version header is written as a '
      'string literal', () {
    expect(headerFindings, isEmpty, reason: headerFindings.join('\n'));
  });

  test('no ?protocol=<digit> query is written as a literal', () {
    expect(queryFindings, isEmpty, reason: queryFindings.join('\n'));
  });
}

/// Every directory named `test`, anywhere under `packages/`, `tool/`,
/// `template/` or `example/` — the trees where a hand-rolled HTTP request
/// can be built or read back. `lib/`, `bin/`, platform folders (`ios/`,
/// `android/`) and the rest are walked only to find a `test` directory
/// inside them; their own contents are never scanned.
List<Directory> _testDirectoriesUnder(Directory root) {
  final scopeRoots = ['packages', 'tool', 'template', 'example']
      .map((name) => Directory(p.join(root.path, name)))
      .where((dir) => dir.existsSync());
  final found = <Directory>[];
  for (final scopeRoot in scopeRoots) {
    for (final entry in scopeRoot.listSync(recursive: true)) {
      if (entry is Directory && p.basename(entry.path) == 'test') {
        found.add(entry);
      }
    }
  }
  return found..sort((a, b) => a.path.compareTo(b.path));
}

Directory _repositoryRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'packages')).existsSync() &&
        Directory(p.join(dir.path, 'toolkit')).existsSync()) {
      return dir;
    }
    final up = dir.parent;
    if (up.path == dir.path) {
      throw StateError('no repository root above ${Directory.current.path}');
    }
    dir = up;
  }
}
