import 'dart:io';

import 'package:path/path.dart' as p;

/// Consolidates agent discovery roots without losing project-owned skills.
class ToolkitSkills {
  ToolkitSkills(Directory project)
    : shared = Directory(p.join(project.path, '.agents', 'skills')),
      claude = Directory(p.join(project.path, '.claude', 'skills'));

  final Directory shared;
  final Directory claude;

  /// Read-only: every conflict is found before the installer writes anything.
  void preflight() {
    final sharedType = FileSystemEntity.typeSync(
      shared.path,
      followLinks: false,
    );
    if (sharedType != FileSystemEntityType.directory &&
        sharedType != FileSystemEntityType.notFound) {
      throw StateError('${shared.path} must be a physical skills directory.');
    }
    final type = FileSystemEntity.typeSync(claude.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      final target = Link(claude.path).targetSync();
      if (p.normalize(p.join(claude.parent.path, target)) !=
          p.normalize(shared.path)) {
        throw StateError(
          'Unexpected skills symlink: ${claude.path} -> $target',
        );
      }
      return;
    }
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw StateError('${claude.path} must be a skills directory.');
    }
    for (final entry in claude.listSync(followLinks: false)) {
      final name = p.basename(entry.path);
      if (name.startsWith('dartway-')) continue;
      final destination = p.join(shared.path, name);
      if (FileSystemEntity.typeSync(destination, followLinks: false) !=
              FileSystemEntityType.notFound &&
          !_same(entry.path, destination)) {
        throw StateError(
          'Conflicting project-owned skill "$name": ${entry.path} and '
          '$destination differ. Resolve the copies and run again; nothing changed.',
        );
      }
    }
  }

  void consolidate({required bool enableClaude}) {
    shared.createSync(recursive: true);
    final type = FileSystemEntity.typeSync(claude.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      if (enableClaude) return;
      Link(claude.path).deleteSync();
    } else if (type == FileSystemEntityType.directory) {
      for (final entry in claude.listSync(followLinks: false)) {
        final name = p.basename(entry.path);
        final destination = p.join(shared.path, name);
        if (!name.startsWith('dartway-') &&
            FileSystemEntity.typeSync(destination, followLinks: false) ==
                FileSystemEntityType.notFound) {
          entry.renameSync(destination);
        }
      }
      claude.deleteSync(recursive: true);
    }
    if (enableClaude) {
      claude.parent.createSync(recursive: true);
      Link(claude.path).createSync('../.agents/skills');
    }
  }

  static bool _same(String left, String right) {
    final type = FileSystemEntity.typeSync(left, followLinks: false);
    if (type != FileSystemEntity.typeSync(right, followLinks: false))
      return false;
    if (type == FileSystemEntityType.link) {
      return Link(left).targetSync() == Link(right).targetSync();
    }
    if (type == FileSystemEntityType.file) {
      final a = File(left).readAsBytesSync();
      final b = File(right).readAsBytesSync();
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (type != FileSystemEntityType.directory) return false;
    final a = Directory(left).listSync(followLinks: false);
    final b = Directory(right).listSync(followLinks: false);
    return a.length == b.length &&
        a.every(
          (entry) => _same(entry.path, p.join(right, p.basename(entry.path))),
        );
  }
}
