import 'dart:io';

import 'package:path/path.dart' as p;

/// Folder names that hold a feature's internals rather than a nested feature.
const dwFeatureInternalFolders = {'widgets', 'logic'};

/// Folders that are never part of the feature tree.
const dwIgnoredFolders = {
  'generated',
  'gen',
  'l10n',
  'zarchive',
  'zarchiv',
  '.dart_tool',
};

/// A node of the project tree below an area (`lib/app`, `lib/admin`, ...).
///
/// The model has exactly two shapes, and which one a folder is is decided by
/// its own content — nothing has to be declared:
///
/// * **feature** — a folder with a root `.dart` file. That single file is the
///   feature's whole public surface; everything else it owns lives in
///   `widgets/` and `logic/`.
/// * **group** — a folder with no root `.dart` file at all. It only groups
///   features and encapsulates nothing, so feature rules do not apply to it.
///
/// A feature may contain nested features; grouping never changes visibility.
class DwFeatureNode {
  DwFeatureNode({
    required this.dir,
    required this.rootFiles,
    required this.children,
    required this.ownFiles,
  });

  final Directory dir;

  /// `.dart` files directly inside [dir] (generated files excluded).
  final List<File> rootFiles;

  /// Nested features and groups.
  final List<DwFeatureNode> children;

  /// Every `.dart` file this node owns — its root file plus `widgets/` and
  /// `logic/`, but not the files of nested features.
  final List<File> ownFiles;

  bool get isGroup => rootFiles.isEmpty;

  bool get isFeature => rootFiles.isNotEmpty;

  String get name => p.basename(dir.path);

  /// The file that is allowed to be imported from outside, or `null` when the
  /// node is a group or its structure is broken.
  File? get entryFile => rootFiles.length == 1 ? rootFiles.single : null;

  Iterable<DwFeatureNode> get descendantsAndSelf sync* {
    yield this;
    for (final child in children) {
      yield* child.descendantsAndSelf;
    }
  }
}

bool _isGeneratedDart(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.gen.dart') ||
    path.endsWith('.freezed.dart');

bool _isIgnoredFolder(String name) =>
    dwIgnoredFolders.contains(name) || name.startsWith('.');

/// Builds the feature tree for an area directory (`lib/app`, `lib/admin`, ...).
List<DwFeatureNode> buildAreaNodes(Directory areaDir) {
  if (!areaDir.existsSync()) return const [];
  return areaDir
      .listSync()
      .whereType<Directory>()
      .where((d) => !_isIgnoredFolder(p.basename(d.path)))
      .where((d) => !dwFeatureInternalFolders.contains(p.basename(d.path)))
      .map(buildNode)
      .toList();
}

/// Builds a single node: its root files, the files it owns, and its children.
DwFeatureNode buildNode(Directory dir) {
  final entries = dir.listSync();

  final rootFiles =
      entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !_isGeneratedDart(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final subDirs = entries
      .whereType<Directory>()
      .where((d) => !_isIgnoredFolder(p.basename(d.path)))
      .toList();

  final ownFiles = <File>[...rootFiles];
  final children = <DwFeatureNode>[];

  for (final sub in subDirs) {
    if (dwFeatureInternalFolders.contains(p.basename(sub.path))) {
      ownFiles.addAll(
        sub
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.dart') && !_isGeneratedDart(f.path),
            ),
      );
    } else {
      children.add(buildNode(sub));
    }
  }

  return DwFeatureNode(
    dir: dir,
    rootFiles: rootFiles,
    children: children,
    ownFiles: ownFiles,
  );
}

/// Resolves the feature that owns [filePath] — the nearest ancestor folder that
/// is a feature, walking out of `widgets/` and `logic/` on the way.
///
/// Returns the feature directory path (normalised with `/`), or `null` when the
/// file sits outside any feature.
String? ownerFeatureOf(String libRelativePath) {
  final parts = p.posix.split(libRelativePath.replaceAll(r'\', '/'));
  if (parts.length < 2) return null;

  // Drop the file name, then climb out of the internal folders.
  final dirParts = parts.sublist(0, parts.length - 1);
  while (dirParts.isNotEmpty &&
      dwFeatureInternalFolders.contains(dirParts.last)) {
    dirParts.removeLast();
  }
  if (dirParts.isEmpty) return null;
  return dirParts.join('/');
}

/// Whether [libRelativePath] is a file kept inside a feature (`widgets/` or
/// `logic/`) — the part of a feature nobody outside it may import.
bool isFeatureInternalPath(String libRelativePath) {
  final parts = p.posix.split(libRelativePath.replaceAll(r'\', '/'));
  return parts
      .sublist(0, parts.length - 1)
      .any(dwFeatureInternalFolders.contains);
}
