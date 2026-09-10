// Puts this tree's framework packages inside a created project.
//
// The work is `package:dartway_cli/src/vendor_framework.dart`, where it can be
// tested; this file is the way CI calls it. See that library for why the image
// check needs it.
//
// Usage: dart run tool/vendor_framework.dart <project-dir> [monorepo-dir]

import 'dart:io';

import 'package:dartway_cli/src/vendor_framework.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/vendor_framework.dart <project-dir> [monorepo-dir]',
    );
    exit(64);
  }

  final project = Directory(args.first);
  if (!project.existsSync()) {
    stderr.writeln('No such project directory: ${project.path}');
    exit(1);
  }

  try {
    vendorFramework(
      project: project,
      monorepo: Directory(args.length > 1 ? args[1] : Directory.current.path),
    ).forEach(stdout.writeln);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exit(1);
  }
}
