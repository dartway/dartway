import 'dart:io';

/// Usage:
/// dart run scripts/rename.dart myapp
void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: dart run scripts/rename.dart <new_project_name>');
    exit(1);
  }

  final newName = args.first.trim();
  final oldName = 'project_name';

  await renameDirsAndFiles(newName, oldName);
}

renameDirsAndFiles(String newName, String oldName) async {
  print('🔄 Renaming project: $oldName → $newName\n');

  // 1. Текстовые замены внутри файлов
  for (final file in getAllFiles()) {
    try {
      final content = await file.readAsString();
      if (content.contains(oldName)) {
        // print('🔍 Found "$oldName" in: ${file.path}');
        final updated = content.replaceAll(oldName, newName);
        await file.writeAsString(updated);
        print('✏️  Updated text in: ${file.path}');
      }
    } catch (e) {
      print('⚠️ Skipped (cannot read): ${file.path} ($e)');
    }
  }

  // 2. Папки client/flutter/server
  final dirsToRename = [
    '${oldName}_client',
    '${oldName}_flutter',
    '${oldName}_server',
  ];
  for (final dir in dirsToRename) {
    final d = Directory(dir);
    if (d.existsSync()) {
      final newPath = dir.replaceAll(oldName, newName);
      try {
        d.renameSync(newPath);
        print('📁 Renamed directory: $dir → $newPath');
      } catch (e) {
        print('⚠️ Could not rename directory $dir ($e)');
      }
    }
  }

  // 3. Главный файл клиента
  final clientFileOld = '${newName}_client/lib/${oldName}_client.dart';
  final clientFileNew = '${newName}_client/lib/${newName}_client.dart';
  final f = File(clientFileOld);
  if (f.existsSync()) {
    try {
      f.renameSync(clientFileNew);
      print('📄 Renamed file: $clientFileOld → $clientFileNew');
    } catch (e) {
      print('⚠️ Could not rename file $clientFileOld ($e)');
    }
  }

  final gitignore = File('.gitignore');
  if (gitignore.existsSync()) {
    gitignore.renameSync('.gitignore.template');
    print('⚠️ .gitignore.template may be removed now.');
  }

  print('\n✅ Everything successfully renamed to $newName!');
}

/// Получаем все файлы для текстовой замены
Iterable<File> getAllFiles() {
  final excludedDirs = [
    '.git',
    '.dart_tool',
    'build',
    'ios',
    'android',
    'windows',
    'macos',
    'linux',
  ];

  final excludedFiles = ['rename_project.dart'];

  final allowedExtensions = [
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.gitignore',
    '.gitattributes',
    '.sh',
    '.bat',
    '.txt',
  ];

  return Directory.current
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            !excludedDirs.any((ex) => f.uri.pathSegments.contains(ex)) &&
            !excludedFiles.any((ex) => f.path.endsWith(ex)) &&
            allowedExtensions.any((ext) => f.path.endsWith(ext)),
      );
}
