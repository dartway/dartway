import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_feature_tree.dart';

/// A file inside a feature that nothing in that feature refers to.
class DwUnusedFeatureFile {
  DwUnusedFeatureFile({required this.file, required this.declaredNames});

  final File file;

  /// The public names a reference to this file would look like — its own, plus
  /// those of the conditional-import trio it belongs to, since the trio is
  /// reached under one name whichever half of it a platform compiles.
  final Set<String> declaredNames;
}

/// Finds the files in a feature's `widgets/`/`logic/` that no other file of the
/// same feature mentions.
///
/// This is the one kind of dead code the analyzer structurally cannot report: a
/// public class is always "possibly used from somewhere else", and only the
/// feature boundary makes "somewhere else" a finite place. Law 3 gives that
/// boundary — nobody outside the feature may import its internals — so the
/// search is one folder deep and the answer is complete rather than a guess.
///
/// Four things a naive version gets wrong, all four found on real code:
///
/// * **A type is not how it is called.** An extension is reached through its
///   member (`list.commentParentOptions`), a notifier through its provider
///   variable (`chatPostsSearchQueryProvider`). Searching for the declared
///   *type* name reports both as dead while they are in daily use — so every
///   public name a file declares counts, members and top-level variables
///   included.
/// * **A function is a declaration too.** A file whose only public member is a
///   top-level function or getter used to index as declaring nothing it is
///   ever called by — while the `final` lines inside that function's body
///   indexed as though they were top-level. The file was then judged on the
///   names of its own locals, which of course appear nowhere else, and buried
///   alive.
/// * **A conditional import is one symbol in several files.** `foo.dart`
///   forwarding to `foo_stub.dart` / `foo_web.dart` is reached under a name
///   none of the three carries alone: the forwarder declares nothing at all,
///   and each half is a platform the other build never compiles. They answer
///   as one file — alive if anything outside the trio uses any of their names,
///   dead together otherwise.
/// * **Dead code keeps dead code alive.** A handler nobody calls still calls
///   its own settings file, so one pass sees only half the corpse. The sweep
///   repeats, ignoring what it has already buried, until a pass finds nothing.
List<DwUnusedFeatureFile> findUnusedFeatureFiles(DwFeatureNode feature) {
  final entry = feature.entryFile;
  if (entry == null) return const [];

  final internalFiles = feature.ownFiles
      .where((file) => file.path != entry.path)
      .toList();
  if (internalFiles.isEmpty) return const [];

  final files = [entry, ...internalFiles];
  final sources = {
    for (final file in files) file.path: file.readAsStringSync(),
  };
  final contents = {
    for (final file in files) file.path: _strip(sources[file.path]!),
  };
  final declarations = {
    for (final file in internalFiles)
      file.path: _declaredNames(contents[file.path]!),
  };

  // A conditional trio is one unit; every other file is a unit of its own.
  final groupOf = _conditionalGroups(sources);
  final members = <String, List<String>>{};
  for (final file in files) {
    members.putIfAbsent(groupOf[file.path]!, () => []).add(file.path);
  }

  final groupNames = {
    for (final group in members.entries)
      group.key: <String>{
        for (final member in group.value) ...?declarations[member],
      },
  };

  final dead = <String>{};

  // Repeat until a pass buries nobody: what a dead file mentions must stop
  // counting as use.
  var buriedSomething = true;
  while (buriedSomething) {
    buriedSomething = false;

    for (final file in internalFiles) {
      if (dead.contains(file.path)) continue;

      final group = members[groupOf[file.path]!]!;
      // The entry point is the feature's public face and is never asked to
      // justify itself — nor is anything a conditional directive ties to it.
      if (group.contains(entry.path)) continue;

      final names = groupNames[groupOf[file.path]!]!;
      if (names.isEmpty) continue;

      final isUsed = contents.entries.any((candidate) {
        if (group.contains(candidate.key) || dead.contains(candidate.key)) {
          return false;
        }
        return names.any((name) => _mentions(candidate.value, name));
      });

      if (!isUsed) {
        dead.addAll(group);
        buriedSomething = true;
      }
    }
  }

  return [
    for (final file in internalFiles)
      if (dead.contains(file.path))
        DwUnusedFeatureFile(
          file: file,
          declaredNames: groupNames[groupOf[file.path]!]!,
        ),
  ];
}

/// Groups the files bound together by a conditional `export`/`import`.
///
/// `export 'foo_stub.dart' if (dart.library.js_interop) 'foo_web.dart';` is one
/// symbol with two implementations. Read file by file each of the three looks
/// unreferenced: the forwarder declares nothing, and the half this build does
/// not compile is named by nobody. Read as a group they answer together.
///
/// Returns a map from every file to the key of its group; a file in no
/// conditional directive is its own group. Only relative uris are followed —
/// a `package:` or `dart:` target is not a file of this feature.
Map<String, String> _conditionalGroups(Map<String, String> sources) {
  final parent = {for (final path in sources.keys) path: path};

  String find(String path) {
    var root = path;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    var step = path;
    while (step != root) {
      final next = parent[step]!;
      parent[step] = root;
      step = next;
    }
    return root;
  }

  void union(String a, String b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA != rootB) parent[rootB] = rootA;
  }

  final byNormalised = {
    for (final path in sources.keys) p.normalize(path): path,
  };

  for (final source in sources.entries) {
    for (final directive in _directive.allMatches(source.value)) {
      final statement = directive.group(0)!;
      if (!_conditionalClause.hasMatch(statement)) continue;

      for (final uri in _quotedUri.allMatches(statement)) {
        final target = uri.group(1)!;
        if (target.contains(':')) continue;
        final resolved =
            byNormalised[p.normalize(p.join(p.dirname(source.key), target))];
        if (resolved != null) union(source.key, resolved);
      }
    }
  }

  return {for (final path in sources.keys) path: find(path)};
}

/// An `export`/`import` statement, read from the unstripped source — [_strip]
/// blanks the very uris this has to see.
final _directive = RegExp(r'^\s*(?:export|import)\s[^;]*;', multiLine: true);

final _conditionalClause = RegExp(r'\bif\s*\(\s*dart\.library\.');

final _quotedUri = RegExp(r'''["']([^"'\n]+)["']''');

/// Comments and string literals are not references: a name inside them proves
/// nothing, and a doc comment naming the class it documents would keep every
/// dead file alive.
String _strip(String source) {
  var text = source;
  text = text.replaceAll(RegExp(r'//.*'), ' ');
  text = text.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
  text = text.replaceAll(RegExp(r"'''.*?'''", dotAll: true), ' ');
  text = text.replaceAll(RegExp(r'""".*?"""', dotAll: true), ' ');
  text = text.replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), ' ');
  text = text.replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), ' ');
  return text;
}

final _typeDeclaration = RegExp(
  r'\b(?:class|mixin|enum|extension type|extension|typedef)\s+(\w+)',
);

/// A top-level `final x = …` / `const x = …` / `Type x = …`, which is how a
/// provider is declared — and a provider is how its notifier is reached.
///
/// Anchored to column 0, and that is the whole point: with the indentation
/// optional the pattern also matched every `final blob = …` inside a function
/// body, so a file whose real declaration the index missed was judged on the
/// names of its own locals and buried for names nothing outside could use.
final _topLevelVariable = RegExp(
  r'^\w[\w<>,\s\?]*\s(\w+)\s*=',
  multiLine: true,
);

/// A top-level function — `Future<void> downloadFile(String name)`. It is
/// called by its own name and by nothing else, and a file whose only public
/// member is one used to read as declaring nothing at all.
final _topLevelFunction = RegExp(
  r'^(?:[\w$][\w<>,\s\?\[\]]*\s+)?(\w+)\s*(?:<[\w\s,<>\?]+>\s*)?\(',
  multiLine: true,
);

/// A top-level getter — `String get appVersion => …`. The same story as the
/// function, in the other spelling.
final _topLevelGetter = RegExp(
  r'^[\w$][\w<>,\s\?\[\]]*\bget\s+(\w+)',
  multiLine: true,
);

/// The members of an extension: an extension is called by member name, never by
/// its own.
final _extensionMember = RegExp(
  r'^\s{2}(?:\w[\w<>,\s\?\[\]]*\s)?(?:get\s+)?(\w+)\s*[({=>]',
  multiLine: true,
);

/// Keywords the patterns can pick up from a line they should not have matched.
/// A name here would silently keep a dead file alive.
const _notNames = {
  'if',
  'for',
  'while',
  'switch',
  'return',
  'assert',
  'super',
  'this',
  'final',
  'const',
  'var',
  'get',
  'set',
  'class',
  'mixin',
  'enum',
  'extension',
  'typedef',
  'import',
  'export',
  'part',
  'library',
};

Set<String> _declaredNames(String source) {
  final names = <String>{
    for (final match in _typeDeclaration.allMatches(source)) match.group(1)!,
    for (final match in _topLevelVariable.allMatches(source)) match.group(1)!,
    for (final match in _topLevelFunction.allMatches(source)) match.group(1)!,
    for (final match in _topLevelGetter.allMatches(source)) match.group(1)!,
  };

  if (source.contains(RegExp(r'\bextension\b'))) {
    names.addAll(
      _extensionMember.allMatches(source).map((match) => match.group(1)!),
    );
  }

  names.removeWhere(_notNames.contains);

  return names;
}

bool _mentions(String source, String name) => RegExp(
  '(?<![A-Za-z0-9_\$])${RegExp.escape(name)}(?![A-Za-z0-9_])',
).hasMatch(source);

/// Every feature under [nodes], the nested ones included.
Iterable<DwFeatureNode> featuresIn(List<DwFeatureNode> nodes) sync* {
  for (final node in nodes) {
    for (final candidate in node.descendantsAndSelf) {
      if (candidate.isFeature) yield candidate;
    }
  }
}

/// lib-relative path with forward slashes, for reporting.
String relativeToLib(String libPath, String filePath) =>
    p.relative(filePath, from: libPath).replaceAll(r'\', '/');
