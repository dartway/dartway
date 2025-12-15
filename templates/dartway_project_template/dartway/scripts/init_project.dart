import 'dart:io';

import 'generate_passwords.dart';
import 'rename_files.dart';

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

  await generatePasswords(newName);
}
