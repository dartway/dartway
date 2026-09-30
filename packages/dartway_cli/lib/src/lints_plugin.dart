import 'dart:io';

import 'package:yaml/yaml.dart';

import 'version_check.dart';

/// What [wireLintsPlugin] did: a [change] it made, or the [manual] edit it
/// could not make safely and hands to the person instead — never both. Both
/// null: the plugin was already wired as asked.
typedef DwLintsWiring = ({String? change, String? manual});

/// Enables the `dartway_lints` analyzer plugin in a Flutter package's
/// [options] (`analysis_options.yaml`), pinned to `^`[version] — or, with
/// [path], to that checkout of the plugin, as `dartway create --framework-path`
/// pins it (dartway/dartway#379).
///
/// The plugin is how a project gets the framework's lint rules, and a project
/// created before `dartway create` wired it never had them: the analysis
/// server runs no plugin it was not told about, and `flutter analyze` runs
/// none at all, so nothing said they were off. `dartway check` fails on it
/// (`lintsPluginMissing`); this is the fix.
///
/// Edits the text rather than re-serialising the YAML, so comments and order
/// survive; keeps the file's line endings and the indentation of the entries
/// beside the one it adds. A caret behind [version] is raised; a plugin
/// already taken from a `path:` is a choice and is left alone. What it cannot
/// edit with certainty — `plugins:` in flow style with entries in it, a
/// `dartway_lints:` in a shape it does not know — it leaves untouched and
/// answers as the edit to make by hand: a guess there writes a second
/// `plugins:` key, which unparses the file and switches every rule off.
DwLintsWiring wireLintsPlugin(File options, String version, {String? path}) {
  final wanted = path == null
      ? 'dartway_lints: ^$version'
      : "dartway_lints:\n      path: '$path'";
  String manual(String why) =>
      '$why — add it by hand in ${options.path}:\n  plugins:\n    $wanted';
  List<String> entry(String indent) => path == null
      ? ['${indent}dartway_lints: ^$version']
      : ['${indent}dartway_lints:', "$indent  path: '$path'"];

  if (!options.existsSync()) {
    options.writeAsStringSync(
      [
        'include: package:flutter_lints/flutter.yaml',
        '',
        "# DartWay's lint rules, run by the analysis server.",
        'plugins:',
        ...entry('  '),
        '',
      ].join('\n'),
    );
    return (
      change:
          'created ${options.path} with flutter_lints and the dartway_lints '
          'plugin',
      manual: null,
    );
  }

  final source = options.readAsStringSync();
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final Object? document;
  try {
    document = loadYaml(source);
  } on YamlException catch (error) {
    return (
      change: null,
      manual: manual('the file does not parse (${error.message})'),
    );
  }
  if (document != null && document is! YamlMap) {
    return (change: null, manual: manual('the file is not a map'));
  }
  final hasPlugins = document is YamlMap && document.containsKey('plugins');
  final plugins = hasPlugins ? document['plugins'] : null;

  if (plugins is YamlMap && plugins.containsKey('dartway_lints')) {
    return _raise(
      options,
      source,
      plugins['dartway_lints'],
      version,
      path,
      manual,
    );
  }

  if (hasPlugins) {
    final headers = _pluginsHeader.allMatches(source).toList();
    final editable = plugins == null || plugins is YamlMap;
    if (headers.length != 1 || !editable) {
      return (
        change: null,
        manual: manual(
          '`plugins:` is written in a form this command does not '
          'edit',
        ),
      );
    }
    final header = headers.single;
    final flow = header[1] != null;
    if (plugins is YamlMap && plugins.isNotEmpty && flow) {
      return (change: null, manual: manual('`plugins:` is a flow map'));
    }
    // Beside the entries already there, at their indentation.
    final sibling = RegExp(
      r'^([ \t]+)[^\s#]',
      multiLine: true,
    ).firstMatch(source.substring(header.end));
    final indent = plugins is YamlMap && plugins.isNotEmpty && sibling != null
        ? sibling[1]!
        : '  ';
    final comment = header[2] == null ? '' : ' ${header[2]}';
    options.writeAsStringSync(
      source.replaceRange(
        header.start,
        header.end,
        ['plugins:$comment', ...entry(indent)].join(eol),
      ),
    );
    return (change: 'enabled the dartway_lints plugin', manual: null);
  }

  final separator = source.isEmpty || source.endsWith('\n') ? '' : eol;
  options.writeAsStringSync(
    '$source$separator${['', "# DartWay's lint rules, run by the analysis server.", 'plugins:', ...entry('  '), ''].join(eol)}',
  );
  return (change: 'enabled the dartway_lints plugin', manual: null);
}

/// A top-level `plugins:` line: bare, or `{}`, with an optional comment. The
/// line end is not part of the match, so a replacement keeps it.
final _pluginsHeader = RegExp(
  r'^plugins:[ \t]*(\{[ \t]*\})?[ \t]*(#[^\r\n]*)?(?=\r?$)',
  multiLine: true,
);

/// The plugin is there already: raise a caret that is behind, leave a path.
DwLintsWiring _raise(
  File options,
  String source,
  Object? current,
  String version,
  String? path,
  String Function(String why) manual,
) {
  if (current is YamlMap && current.containsKey('path')) {
    return (change: null, manual: null);
  }
  if (path != null) {
    return (
      change: null,
      manual: manual(
        'the plugin is pinned to `$current`, and a checkout was '
        'asked for',
      ),
    );
  }
  final caret = current is String
      ? current
      : current is YamlMap && current['version'] is String
      ? current['version'] as String
      : null;
  final floor = caret == null
      ? null
      : RegExp(r'^\^?\s*(\d\S*)$').firstMatch(caret.trim())?.group(1);
  if (caret == null || floor == null) {
    return (
      change: null,
      manual: manual(
        '`dartway_lints: ${current ?? ''}` is neither a caret '
        'nor a path',
      ),
    );
  }
  if (isPackageAtLeastVersion(floor, version)) {
    return (change: null, manual: null);
  }
  final key = current is String ? 'dartway_lints' : 'version';
  final line = RegExp(
    '^([ \\t]+$key:[ \\t]*)[\'"]?${RegExp.escape(caret)}[\'"]?'
    r'(?=[ \t]*(#[^\r\n]*)?\r?$)',
    multiLine: true,
  );
  if (line.allMatches(source).length != 1) {
    return (
      change: null,
      manual: manual('the pin `$caret` could not be found to raise'),
    );
  }
  options.writeAsStringSync(
    source.replaceFirstMapped(line, (m) => '${m[1]}^$version'),
  );
  return (
    change: 'raised the dartway_lints plugin from $caret to ^$version',
    manual: null,
  );
}
