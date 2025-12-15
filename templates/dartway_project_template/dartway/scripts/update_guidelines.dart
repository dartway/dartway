import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  print('🔄 Updating DartWay Guidelines for Project Template (no subtree)...');

  await _ensureRemote();

  // 1. Подтянуть свежие изменения из remote
  final fetch = await Process.run('git', [
    'fetch',
    'dartway_guidelines',
    'main',
  ]);
  if (fetch.exitCode != 0) {
    stderr.writeln('❌ Git fetch failed:\n${fetch.stderr}');
    exit(1);
  }
  print('✅ Guidelines fetched from remote.');

  // 2. Foundations → .cursor/rules/foundations
  _copyDocsFromGit(
    'dev-guidelines/foundations',
    '.cursor/rules/dartway_rules',
    changeExtensionToMdc: true,
  );

  // 3. Flutter → <project_name>_flutter/.cursor/rules/flutter
  final flutterDir = _findDirWithSuffix('_flutter');
  if (flutterDir != null) {
    _copyDocsFromGit(
      'dev-guidelines/flutter',
      '${flutterDir.path}/.cursor/rules/dartway_rules',
      changeExtensionToMdc: true,
    );
  } else {
    print('⚠️ No *_flutter directory found');
  }

  // 4. Server → <project_name>_server/.cursor/rules/server
  final serverDir = _findDirWithSuffix('_server');
  if (serverDir != null) {
    _copyDocsFromGit(
      'dev-guidelines/server',
      '${serverDir.path}/.cursor/rules/dartway_rules',
      changeExtensionToMdc: true,
    );
  } else {
    print('⚠️ No *_server directory found');
  }

  // 5. Docs → project_template/docs
  _copyDocsFromGit('docs', 'project_template/docs');

  print('✨ Guidelines synced into Project Template!');
}

Future<void> _ensureRemote() async {
  final result = await Process.run('git', ['remote']);
  if (result.exitCode != 0) {
    throw Exception('git remote failed: ${result.stderr}');
  }

  final remotes =
      (result.stdout as String)
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  if (!remotes.contains('dartway_guidelines')) {
    print('➕ Adding remote dartway_guidelines...');
    final add = await Process.run('git', [
      'remote',
      'add',
      'dartway_guidelines',
      'https://github.com/dartway/dartway_guidelines.git',
    ]);
    if (add.exitCode != 0) {
      throw Exception('git remote add failed: ${add.stderr}');
    }
    print('✅ Remote dartway_guidelines added.');
  } else {
    print('✅ Remote dartway_guidelines already exists.');
  }
}

Directory? _findDirWithSuffix(String suffix) {
  final root = Directory.current;
  for (final entity in root.listSync()) {
    if (entity is Directory && entity.path.endsWith(suffix)) {
      return entity;
    }
  }
  return null;
}

void _copyDocsFromGit(
  String sourcePath,
  String destinationPath, {
  bool changeExtensionToMdc = false,
}) {
  final destDir = Directory(destinationPath);
  if (!destDir.existsSync()) {
    destDir.createSync(recursive: true);
  }

  // удаляем старые файлы (.md и .mdc), оставляем служебные json
  for (final entity in destDir.listSync(recursive: true)) {
    if (entity is File &&
        (entity.path.endsWith('.md') || entity.path.endsWith('.mdc'))) {
      entity.deleteSync();
    }
  }

  // достаём список файлов в директории из remote
  final lsTree = Process.runSync('git', [
    'ls-tree',
    '-r',
    '--name-only',
    'dartway_guidelines/main',
    sourcePath,
  ]);

  if (lsTree.exitCode != 0) {
    stderr.writeln('⚠️ Failed to list files for $sourcePath: ${lsTree.stderr}');
    return;
  }

  final files = (lsTree.stdout as String)
      .split('\n')
      .where((f) => f.endsWith('.md'));

  for (final file in files) {
    if (file.isEmpty) continue;

    final content = Process.runSync('git', [
      'show',
      'dartway_guidelines/main:$file',
    ], stdoutEncoding: utf8);

    if (content.exitCode != 0) {
      stderr.writeln('⚠️ Failed to read file $file: ${content.stderr}');
      continue;
    }

    final relativePath = file.replaceFirst(sourcePath, '');
    var destFilePath = '$destinationPath$relativePath';

    if (changeExtensionToMdc) {
      destFilePath = destFilePath.replaceAll(RegExp(r'\.md$'), '.mdc');
    }

    final destFile = File(destFilePath);
    destFile.parent.createSync(recursive: true);
    destFile.writeAsStringSync(content.stdout as String, encoding: utf8);

    print('📄 $file → ${destFile.path}');
  }

  print('📂 Copied docs: $sourcePath → $destinationPath');
}
