import 'dart:io';

import 'package:yaml/yaml.dart';

import 'version_check.dart';

/// Enables the `dartway_lints` analyzer plugin in a Flutter package's
/// [options] (`analysis_options.yaml`) at `^`[version], or raises a caret
/// that is behind it (dartway/dartway#379).
///
/// The plugin is how a project gets the framework's lint rules, and a project
/// created before `dartway create` wired it never had them: the analysis
/// server runs no plugin it was not told about, and `flutter analyze` runs
/// none at all, so nothing said they were off. `dartway check` now fails on
/// it (`lintsPluginMissing`); this is the fix, pinned the way `create` pins
/// it — the published version the channel carries.
///
/// Edits the text rather than re-serialising the YAML, so the file's comments
/// and order survive. A plugin named by `path:` is a checkout someone chose
/// and is left alone. Answers what changed, or null when nothing did.
String? wireLintsPlugin(File options, String version) {
  final pin = '  dartway_lints: ^$version';
  if (!options.existsSync()) {
    options.writeAsStringSync('plugins:\n$pin\n');
    return 'created ${options.path} with the dartway_lints plugin ^$version';
  }

  final source = options.readAsStringSync();
  final Object? document;
  try {
    document = loadYaml(source);
  } on YamlException {
    return null;
  }
  final plugins = document is YamlMap ? document['plugins'] : null;

  if (plugins is YamlMap && plugins.containsKey('dartway_lints')) {
    final current = plugins['dartway_lints'];
    if (current is! String) return null;
    final caret = RegExp(r'^\^?(\S+)$').firstMatch(current.trim())?.group(1);
    if (caret == null || isPackageAtLeastVersion(caret, version)) return null;
    final line = RegExp(r'^(\s+dartway_lints:)\s*\S+[ \t]*$', multiLine: true);
    if (!line.hasMatch(source)) return null;
    options.writeAsStringSync(
      source.replaceFirstMapped(line, (match) => '${match[1]} ^$version'),
    );
    return 'raised the dartway_lints plugin from $current to ^$version';
  }

  final section = RegExp(r'^plugins:[ \t]*$', multiLine: true);
  final wired = section.hasMatch(source)
      ? source.replaceFirstMapped(section, (match) => '${match[0]}\n$pin')
      : '${source.endsWith('\n') ? source : '$source\n'}'
            '\n# DartWay\'s lint rules, run by the analysis server.\n'
            'plugins:\n$pin\n';
  options.writeAsStringSync(wired);
  return 'enabled the dartway_lints plugin ^$version';
}
