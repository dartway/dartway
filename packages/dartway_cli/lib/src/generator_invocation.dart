import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs the already-resolved generator directly. `dart run` may implicitly
/// resolve dependencies and rewrite locks/configuration even for --check.
List<String>? resolvedGeneratorArguments(
  String packageRoot,
  List<String> arguments,
) {
  var current = p.normalize(p.absolute(packageRoot));
  while (true) {
    final config = File(p.join(current, '.dart_tool/package_config.json'));
    if (config.existsSync()) {
      try {
        final decoded = jsonDecode(config.readAsStringSync());
        if (decoded is! Map ||
            decoded['configVersion'] != 2 ||
            decoded['packages'] is! List)
          return null;
        for (final entry in decoded['packages'] as List) {
          if (entry is! Map ||
              entry['name'] != 'dartway_generator' ||
              entry['rootUri'] is! String)
            continue;
          final root = config.uri.resolve(entry['rootUri'] as String);
          if (root.scheme != 'file') return null;
          final script = File(
            p.join(root.toFilePath(), 'bin/dartway_generator.dart'),
          );
          if (!script.existsSync()) return null;
          return ['--packages=${config.path}', script.path, ...arguments];
        }
      } on FormatException {
        return null;
      }
      return null;
    }
    final parent = p.dirname(current);
    if (parent == current) return null;
    current = parent;
  }
}
