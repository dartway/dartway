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
      final dependency = _pluginDependency(
        (document['plugins'] as YamlMap)['dartway_lints'],
        options,
      );
      File(p.join(scratch.path, 'pubspec.yaml')).writeAsStringSync(
        'name: dartway_plugin_preflight\n'
        'environment:\n  sdk: ">=3.11.0 <4.0.0"\n'
        'dependencies:\n${_nativeDependencyYaml(dependency)}',
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

/// Native plugin options are not pub dependency options: diagnostics stay in
/// the original YAML. Native analysis selects version, then git, then path;
/// pub can select differently from a mixed map, so never guess between sources.
Object _pluginDependency(Object? plugin, File options) {
  Never invalid(String reason) => throw StateError(
    'Invalid dartway_lints plugin source in ${options.path}: $reason. '
    'Project configuration left untouched.',
  );
  String text(Object? value, String field, {bool allowEmpty = false}) {
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      invalid(
        '$field must be ${allowEmpty ? 'a string' : 'a nonempty string'}',
      );
    }
    return value;
  }

  if (plugin is String) return text(plugin, 'version');
  if (plugin is! YamlMap) invalid('expected a version or source map');
  final sources = [
    for (final field in ['version', 'git', 'path'])
      if (plugin.containsKey(field)) field,
  ];
  if (sources.length != 1) {
    invalid('choose exactly one of version, git or path');
  }
  final source = sources.single;
  if (plugin.containsKey('hosted') && source != 'version') {
    invalid('hosted requires a version source');
  }
  if (source == 'version') {
    return {
      'version': text(plugin['version'], 'version'),
      if (plugin.containsKey('hosted'))
        'hosted': text(plugin['hosted'], 'hosted'),
    };
  }
  if (source == 'path') {
    return {
      'path': p.normalize(
        p.join(options.parent.absolute.path, text(plugin['path'], 'path')),
      ),
    };
  }
  final git = plugin['git'];
  if (git is String) return {'git': text(git, 'git')};
  if (git is! YamlMap) invalid('git must be a URL or source map');
  const fields = {'url', 'ref', 'path', 'tag_pattern'};
  if (git.keys.any((key) => !fields.contains(key))) {
    invalid('git supports only url, ref, path and tag_pattern');
  }
  text(git['url'], 'git.url');
  return {
    'git': {
      for (final field in git.keys)
        field as String: text(
          git[field],
          'git.$field',
          allowEmpty: field != 'url',
        ),
    },
  };
}

/// The native analyzer writes this dependency YAML into its synthetic package:
/// paths are JSON-quoted, while hosted/version and Git fields are raw scalars.
/// Resolving JSON instead could falsely accept a quoted Git ref such as "true",
/// which native YAML turns into a boolean. This affects only the scratch
/// pubspec; the owner's plugin configuration is never reserialized.
String _nativeDependencyYaml(Object dependency) {
  if (dependency is String) return '  dartway_lints: $dependency\n';
  final source = dependency as Map;
  if (source.containsKey('path')) {
    return '  dartway_lints:\n    path: ${jsonEncode(source['path'])}\n';
  }
  if (source.containsKey('git')) {
    final git = source['git'] is String
        ? {'url': source['git']}
        : source['git'] as Map;
    return '  dartway_lints:\n    git:\n${[
      for (final field in ['url', 'ref', 'path', 'tag_pattern'])
        if (git.containsKey(field)) '      $field: ${git[field]}\n',
    ].join()}';
  }
  if (!source.containsKey('hosted')) {
    return '  dartway_lints: ${source['version']}\n';
  }
  return '  dartway_lints:\n    version: ${source['version']}\n'
      '    hosted: ${source['hosted']}\n';
}
