import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_feature_tree.dart';

/// A file inside a feature that nothing in that feature refers to.
class DwUnusedFeatureFile {
  DwUnusedFeatureFile({required this.file, required this.declaredNames});

  final File file;

  /// The public names the file declares — what a reference to it would look
  /// like.
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
/// Two things a naive version gets wrong, both found on real code:
///
/// * **A type is not how it is called.** An extension is reached through its
///   member (`list.commentParentOptions`), a notifier through its provider
///   variable (`chatPostsSearchQueryProvider`). Searching for the declared
///   *type* name reports both as dead while they are in daily use — so every
///   public name a file declares counts, members and top-level variables
///   included.
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

  final contents = {
    for (final file in [entry, ...internalFiles]) file.path: _strip(file),
  };
  final declarations = {
    for (final file in internalFiles) file.path: _declaredNames(contents[file.path]!),
  };

  final dead = <String>{};

  // Repeat until a pass buries nobody: what a dead file mentions must stop
  // counting as use.
  var buriedSomething = true;
  while (buriedSomething) {
    buriedSomething = false;

    for (final file in internalFiles) {
      if (dead.contains(file.path)) continue;

      final names = declarations[file.path]!;
      if (names.isEmpty) continue;

      final isUsed = contents.entries.any((entry) {
        if (entry.key == file.path || dead.contains(entry.key)) return false;
        return names.any((name) => _mentions(entry.value, name));
      });

      if (!isUsed) {
        dead.add(file.path);
        buriedSomething = true;
      }
    }
  }

  return [
    for (final file in internalFiles)
      if (dead.contains(file.path))
        DwUnusedFeatureFile(
          file: file,
          declaredNames: declarations[file.path]!,
        ),
  ];
}

/// Comments and string literals are not references: a name inside them proves
/// nothing, and a doc comment naming the class it documents would keep every
/// dead file alive.
String _strip(File file) {
  var text = file.readAsStringSync();
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
final _topLevelVariable = RegExp(
  r'^(?:final|const|late final)?\s*\w[\w<>,\s\?]*\s(\w+)\s*=',
  multiLine: true,
);

/// The members of an extension: an extension is called by member name, never by
/// its own.
final _extensionMember = RegExp(
  r'^\s{2}(?:\w[\w<>,\s\?\[\]]*\s)?(?:get\s+)?(\w+)\s*[({=>]',
  multiLine: true,
);

Set<String> _declaredNames(String source) {
  final names = <String>{
    for (final match in _typeDeclaration.allMatches(source)) match.group(1)!,
    for (final match in _topLevelVariable.allMatches(source)) match.group(1)!,
  };

  if (source.contains(RegExp(r'\bextension\b'))) {
    names.addAll(
      _extensionMember.allMatches(source).map((match) => match.group(1)!),
    );
  }

  // Keywords the member pattern can pick up in a body it should not have
  // matched. A name here would silently keep a dead file alive.
  names.removeWhere(
    (name) => const {
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
    }.contains(name),
  );

  return names;
}

bool _mentions(String source, String name) =>
    RegExp('(?<![A-Za-z0-9_\$])${RegExp.escape(name)}(?![A-Za-z0-9_])')
        .hasMatch(source);

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
