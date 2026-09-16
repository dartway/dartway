import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The prose of this repository names only what the code declares.
///
/// The documentation (`docs/`), the agent toolkit (`toolkit/`) and the two
/// root files are read by people and by agents, and both believe them. A page
/// naming a class that was renamed compiles nowhere and fails nothing — it
/// sends the next reader to write code against an API that does not exist,
/// which is how this repository once shipped a toolkit teaching a data layer
/// deleted a year earlier.
///
/// So three things are checked mechanically, against the code on this
/// commit:
///
/// - every `Dw…` type named in the prose is declared in a public library of
///   the monorepo — `packages/<package>/lib/<library>.dart` and what it
///   exports, honouring `show` and `hide`, without `@internal` declarations —
///   or among the CLI's checks, which are the CLI's public surface;
/// - every `dw.<member>` is a member of the app core (`DwFlutterToolbox`,
///   `DwFlutterCore` and their extensions) or a `dw.` code the framework
///   sends on the wire;
/// - every relative link in `docs/` resolves.
///
/// What it cannot see is whether a sample's *signature* is right; a sample is
/// still to be lifted from `example/` or `template/` where it can be.
void main() {
  final root = _repositoryRoot();
  final surface = _PublicSurface(root);
  final docs = Directory(p.join(root.path, 'docs'));

  final excluded = [
    // `docs/1.0/` is the rewrite's own history: its decisions quote the names
    // they replaced.
    p.join(docs.path, '1.0'),
    // A migration note is addressed to a project that is *behind*, and its
    // whole subject is the name that no longer exists. Checking it against
    // today's surface would make every rename note fail the day it is written.
    p.join(docs.path, 'migrations'),
  ];

  final prose = [
    for (final file in _markdownUnder(docs))
      if (!excluded.any((dir) => p.isWithin(dir, file.path))) file,
    ..._markdownUnder(Directory(p.join(root.path, 'toolkit'))),
    File(p.join(root.path, 'README.md')),
    File(p.join(root.path, 'CLAUDE.md')),
  ];

  /// What is wrong with [file], by check.
  ({List<String> types, List<String> members, List<String> links}) findingsIn(
    File file,
  ) {
    final where = _relative(root, file);
    final lines = file.readAsLinesSync();
    final types = <String>[];
    final members = <String>[];
    for (var i = 0; i < lines.length; i++) {
      for (final match in _typeName.allMatches(lines[i])) {
        final name = match.group(0)!;
        if (!surface.types.contains(name)) types.add('$name — $where:${i + 1}');
      }
      for (final match in _dwMember.allMatches(lines[i])) {
        final member = match.group(1)!;
        if (!surface.dwMembers.contains(member) &&
            !surface.wireCodes.contains(member)) {
          members.add('dw.$member — $where:${i + 1}');
        }
      }
    }
    final links = <String>[];
    if (p.isWithin(docs.path, file.path)) {
      final text = file.readAsStringSync().replaceAll(_fencedBlock, '');
      for (final match in _link.allMatches(text)) {
        final target = match.group(1)!.split('#').first.trim();
        if (target.isEmpty || _external.hasMatch(target)) continue;
        final resolved = p.normalize(p.join(file.parent.path, target));
        if (FileSystemEntity.typeSync(resolved) ==
            FileSystemEntityType.notFound) {
          links.add('$target — $where');
        }
      }
    }
    return (types: types, members: members, links: links);
  }

  final checked = [
    for (final file in prose)
      if (!_portInFlight.contains(_relative(root, file))) findingsIn(file),
  ];

  test('every Dw type named in the prose is declared and public', () {
    expect(
      [for (final findings in checked) ...findings.types],
      isEmpty,
      reason:
          'named in the prose, declared in no public library of packages/ — '
          'renamed, removed, internal, or never there',
    );
  });

  test('every dw.<member> in the prose exists on the app core', () {
    expect(
      [for (final findings in checked) ...findings.members],
      isEmpty,
      reason:
          'neither a member of DwFlutterToolbox / DwFlutterCore nor a dw. code the '
          'framework sends',
    );
  });

  test('every relative link in docs/ resolves', () {
    expect(
      [for (final findings in checked) ...findings.links],
      isEmpty,
      reason: 'links to nothing',
    );
  });

  test('the pages excused while their subsystem is ported still need it', () {
    final stale = <String>[];
    for (final path in _portInFlight) {
      final file = File(p.join(root.path, path));
      if (!file.existsSync()) {
        stale.add('$path — gone');
        continue;
      }
      final findings = findingsIn(file);
      if (findings.types.isEmpty &&
          findings.members.isEmpty &&
          findings.links.isEmpty) {
        stale.add('$path — passes every check');
      }
    }
    expect(
      stale,
      isEmpty,
      reason:
          'take these off `_portInFlight` in this test: an excuse that is no '
          'longer needed hides the next drift on that page',
    );
  });
}

/// Pages of a subsystem being ported to the rewrite in its own change, named
/// one by one so the exception is visible, and checked to still be needed — a
/// page that passes, or is gone, fails the suite until it is taken off. Push
/// (D-010, D-033) is ported, its pages with it: none is excused now.
const _portInFlight = <String>{};

final _typeName = RegExp(r'\bDw[A-Z][A-Za-z0-9]*\b');

/// `dw.request(`, `dw.notify.success` — the member right after `dw.`, not a
/// longer word ending in `dw` (`pdw.x`) and not a path (`dw_…`).
final _dwMember = RegExp(r'(?<![\w.])dw\.([a-zA-Z]\w*)');

final _fencedBlock = RegExp(r'^```.*?^```', multiLine: true, dotAll: true);
final _link = RegExp(r'\]\(([^)\s]+)(?:\s+"[^"]*")?\)');
final _external = RegExp(r'^(?:[a-z][a-z0-9+.-]*:|//)');

List<File> _markdownUnder(Directory directory) =>
    directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _relative(Directory root, File file) =>
    p.relative(file.path, from: root.path).replaceAll(r'\', '/');

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

/// What the monorepo's packages offer by name, read from their sources.
///
/// Read with patterns rather than an analyzer: the sources are `dart format`
/// output, so a top-level declaration starts its line, and this suite then
/// needs neither a resolved Flutter SDK nor a pinned analyzer to answer.
final class _PublicSurface {
  _PublicSurface(this.root) {
    final packages = Directory(p.join(root.path, 'packages'));
    for (final package in packages.listSync().whereType<Directory>()) {
      final lib = Directory(p.join(package.path, 'lib'));
      if (!lib.existsSync()) continue;
      for (final library in lib.listSync().whereType<File>()) {
        if (library.path.endsWith('.dart')) {
          types.addAll(_exportedBy(library, const {}));
        }
      }
    }
    // The CLI publishes no library; its checks are its public surface.
    final checker = Directory(
      p.join(packages.path, 'dartway_cli', 'lib', 'src', 'checker'),
    );
    for (final file in checker.listSync().whereType<File>()) {
      types.addAll(_declaredIn(file));
    }

    final core = p.join(packages.path, 'dartway_core_flutter', 'lib', 'src');
    for (final (path, owner) in [
      (p.join(core, 'core', 'dw_flutter_toolbox.dart'), 'DwFlutterToolbox'),
      (p.join(core, 'data', 'dw_flutter_core.dart'), 'DwFlutterCore'),
    ]) {
      dwMembers.addAll(_membersOf(File(path).readAsStringSync(), owner));
    }
    for (final file in Directory(
      core,
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in _extensionOnCore.allMatches(source)) {
        dwMembers.addAll(_membersOf(source, match.group(1)!, extension: true));
      }
    }

    for (final package in packages.listSync().whereType<Directory>()) {
      final lib = Directory(p.join(package.path, 'lib'));
      if (!lib.existsSync()) continue;
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        wireCodes.addAll(
          _wireCodeLiteral.allMatches(source).map((m) => m.group(1)!),
        );
        if (p.basename(file.path) == 'dw_call_refusal.dart') {
          // `DwCoreRefusal.code` is `'dw.$name'`: its values are the codes.
          final body = RegExp(
            r'enum DwCoreRefusal[^{]*\{(.*?)\n  @override',
            dotAll: true,
          ).firstMatch(source)!.group(1)!;
          wireCodes.addAll(
            RegExp(
              r'^  ([a-z]\w*)[,;]',
              multiLine: true,
            ).allMatches(body).map((m) => m.group(1)!),
          );
        }
      }
    }
  }

  final Directory root;
  final Set<String> types = {};
  final Set<String> dwMembers = {};
  final Set<String> wireCodes = {};

  static final _extensionOnCore = RegExp(
    r'^extension (\w+) on DwFlutterToolbox(?:Core)?\b',
    multiLine: true,
  );
  static final _wireCodeLiteral = RegExp(r'''['"]dw\.([a-zA-Z]\w*)''');

  /// Names a library file makes visible: its own declarations and its parts',
  /// then what it exports, filtered by `show` and `hide`.
  Set<String> _exportedBy(File library, Set<String> visiting) {
    final path = p.normalize(library.absolute.path);
    if (visiting.contains(path) || !library.existsSync()) return {};
    final seen = {...visiting, path};
    final source = library.readAsStringSync();
    final names = {..._declaredIn(library)};
    for (final part in _part.allMatches(source)) {
      names.addAll(
        _declaredIn(File(p.join(library.parent.path, part.group(1)!))),
      );
    }
    for (final export in _export.allMatches(source)) {
      final target = _resolve(library, export.group(1)!);
      if (target == null) continue; // a package outside the monorepo
      var exported = _exportedBy(target, seen);
      final combinators = export.group(2) ?? '';
      for (final combinator in _combinator.allMatches(combinators)) {
        final listed = combinator
            .group(2)!
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet();
        exported = combinator.group(1) == 'show'
            ? exported.intersection(listed)
            : exported.difference(listed);
      }
      names.addAll(exported);
    }
    return names;
  }

  File? _resolve(File from, String uri) {
    if (uri.startsWith('dart:')) return null;
    final package = RegExp(r'^package:(\w+)/(.+)$').firstMatch(uri);
    if (package == null) {
      return File(p.join(from.parent.path, uri));
    }
    final file = File(
      p.join(
        root.path,
        'packages',
        package.group(1)!,
        'lib',
        package.group(2)!,
      ),
    );
    return file.existsSync() ? file : null;
  }

  static final _part = RegExp(
    r'''^part\s+['"]([^'"]+)['"]\s*;''',
    multiLine: true,
  );
  static final _export = RegExp(
    r'''^export\s+['"]([^'"]+)['"]((?:\s+(?:show|hide)\s+[\w\s,]+)*)\s*;''',
    multiLine: true,
  );
  static final _combinator = RegExp(
    r'(show|hide)\s+([\w\s,]+?)(?=\s+(?:show|hide)\b|$)',
  );

  /// Top-level type declarations of [file] that are not `@internal`.
  static Set<String> _declaredIn(File file) {
    if (!file.existsSync()) return {};
    final lines = file.readAsLinesSync();
    final names = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final match = _declaration.firstMatch(lines[i]);
      if (match == null) continue;
      var above = i - 1;
      while (above >= 0 && lines[above].startsWith('///')) {
        above--;
      }
      final internal = above >= 0 && lines[above].trim() == '@internal';
      if (!internal) names.add(match.group(1)!);
    }
    return names;
  }

  static final _declaration = RegExp(
    r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
    r'(?:class|mixin|enum|typedef|extension(?:\s+type)?)\s+(Dw\w+)',
  );

  /// Member names declared in the body of `class|extension [owner]`: every
  /// identifier that starts a declaration at the body's indentation.
  static Set<String> _membersOf(
    String source,
    String owner, {
    bool extension = false,
  }) {
    final start = RegExp(
      extension
          ? '^extension $owner on [^{]*\\{'
          : '^(?:\\w+\\s+)*class $owner\\b[^{]*\\{',
      multiLine: true,
    ).firstMatch(source);
    if (start == null) {
      throw StateError('no declaration of $owner to read members from');
    }
    final body = source.substring(start.end);
    final end = RegExp(r'^\}', multiLine: true).firstMatch(body);
    return _member
        .allMatches(body.substring(0, end?.start ?? body.length))
        .map((match) => match.group(1)!)
        .toSet();
  }

  static final _member = RegExp(
    r'^  (?:(?:static|late|final|const|external|covariant)\s+)*'
    r'(?:[A-Za-z_][\w<>?,. ]*?\s+)?(?:get\s+|set\s+)?([a-z]\w*)\s*(?:\(|=>|=|;|<|\{)',
    multiLine: true,
  );
}
