import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'lints_plugin.dart';

/// Stages the exact YAML edit and asks pub to resolve its plugin dependency in
/// isolation, including transitive analyzer constraints. A failed resolution
/// never reaches the project's analysis options or toolkit installer.
class DwLintsPlan {
  DwLintsPlan._(this.contents, this.change, this.sourceDescription);
  final String contents;
  final String? change;
  final String sourceDescription;

  static Future<DwLintsPlan> preflight(
    File options,
    String version, {
    String? path,
  }) async {
    final scratch = Directory.systemTemp.createTempSync('dw-plugin-preflight-');
    try {
      final staged = File(p.join(scratch.path, 'analysis_options.yaml'));
      if (options.existsSync()) options.copySync(staged.path);
      final wiring = wireLintsPlugin(staged, version, path: path);
      if (wiring.manual != null) {
        throw StateError(wiring.manual!.replaceAll(staged.path, options.path));
      }
      final contents = staged.readAsStringSync();
      final document = loadYaml(contents) as YamlMap;
      final plugin = (document['plugins'] as YamlMap)['dartway_lints'];
      Object plain(Object? value) {
        if (value is Map) {
          return {
            for (final entry in value.entries)
              entry.key.toString(): plain(entry.value),
          };
        }
        if (value is List) return value.map(plain).toList();
        return value ?? '';
      }

      var dependency = plain(plugin);
      if (dependency is Map && dependency['path'] is String) {
        dependency = {
          ...dependency,
          'path': p.normalize(
            p.join(options.parent.absolute.path, dependency['path'] as String),
          ),
        };
      }
      File(p.join(scratch.path, 'pubspec.yaml')).writeAsStringSync(
        jsonEncode({
          'name': 'dartway_plugin_preflight',
          'environment': {'sdk': '>=3.11.0 <4.0.0'},
          'dependencies': {'dartway_lints': dependency},
        }),
      );
      final running = p.basenameWithoutExtension(Platform.resolvedExecutable);
      final dart = running == 'dart' ? Platform.resolvedExecutable : 'dart';
      final result = await Process.run(dart, [
        'pub',
        'get',
      ], workingDirectory: scratch.path);
      if (result.exitCode != 0) {
        throw StateError(
          'Analyzer plugin source is not resolvable; project '
          'configuration left untouched.\n${result.stdout}\n${result.stderr}',
        );
      }
      final lock =
          loadYaml(
                File(p.join(scratch.path, 'pubspec.lock')).readAsStringSync(),
              )
              as YamlMap;
      final resolved =
          (lock['packages'] as YamlMap)['dartway_lints'] as YamlMap;
      return DwLintsPlan._(
        contents,
        wiring.change?.replaceAll(staged.path, options.path),
        '${jsonEncode(dependency)} → ${resolved['version']} (${resolved['source']})',
      );
    } finally {
      scratch.deleteSync(recursive: true);
    }
  }

  void apply(File options) {
    if (change != null) options.writeAsStringSync(contents);
  }
}
