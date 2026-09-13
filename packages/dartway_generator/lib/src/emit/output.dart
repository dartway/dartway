import 'dart:io';

import 'package:analyzer/dart/analysis/formatter_options.dart' as analyzer;
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../project.dart';
import 'source_text.dart';

/// A file the generator produces, already formatted.
final class GeneratedFile {
  const GeneratedFile(this.path, this.content);

  final String path;
  final String content;
}

/// Formats [source] the way `dart format` would in the owning package: at its
/// language version, page width and trailing-comma setting, so the committed
/// output never differs from a format pass over it.
String formatDart(
  String source, {
  required Version languageVersion,
  required analyzer.FormatterOptions options,
  required String path,
}) {
  final version = languageVersion > DartFormatter.latestLanguageVersion
      ? DartFormatter.latestLanguageVersion
      : languageVersion;
  final formatter = DartFormatter(
    languageVersion: version,
    pageWidth: options.pageWidth,
    trailingCommas: switch (options.trailingCommas) {
      analyzer.TrailingCommas.preserve => TrailingCommas.preserve,
      _ => TrailingCommas.automate,
    },
    lineEnding: '\n',
  );
  try {
    return formatter.format(source, uri: path);
  } on FormatterException catch (error) {
    // Generated code that does not parse is a generator bug; show the source
    // so it can be reported with the exact input.
    throw StateError(
      'dartway_generator produced code that does not parse for $path — '
      'please report this.\n${error.message()}\n--- source ---\n$source',
    );
  }
}

/// What a run changes on disk.
final class OutputPlan {
  OutputPlan({
    required this.written,
    required this.unchanged,
    required this.removed,
    required this.contents,
  });

  final List<String> written;
  final List<String> unchanged;
  final List<String> removed;
  final Map<String, String> contents;

  /// Writes and removes files. Nothing is touched when the content is already
  /// there, so file timestamps (and incremental tools watching them) stay put.
  void apply() {
    for (final path in written) {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents[path]!);
    }
    for (final path in removed) {
      File(path).deleteSync();
    }
  }
}

/// Compares [files] with the disk and finds stale generated parts.
OutputPlan planOutput(List<GeneratedFile> files, List<DwPackage> packages) {
  final written = <String>[];
  final unchanged = <String>[];
  final contents = <String, String>{};
  for (final file in files) {
    contents[file.path] = file.content;
    final existing = File(file.path);
    if (existing.existsSync() && existing.readAsStringSync() == file.content) {
      unchanged.add(file.path);
    } else {
      written.add(file.path);
    }
  }

  final removed = <String>[];
  for (final package in packages) {
    final lib = Directory(package.lib);
    if (!lib.existsSync()) continue;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dw.dart')) continue;
      final path = p.normalize(entity.path);
      if (contents.containsKey(path)) continue;
      if (_isStalePart(entity)) removed.add(path);
    }
  }
  written.sort();
  unchanged.sort();
  removed.sort();
  return OutputPlan(
    written: written,
    unchanged: unchanged,
    removed: removed,
    contents: contents,
  );
}

/// A part is stale when it is ours (starts with the header) and its source no
/// longer declares it. The source is checked textually rather than trusted to
/// the analysis: a library that failed to analyze must not lose its part.
bool _isStalePart(File part) {
  final String first;
  try {
    first = part.readAsLinesSync().firstOrNull ?? '';
  } on FileSystemException {
    return false;
  }
  if (first.trim() != generatedHeader) return false;
  final partName = p.basename(part.path);
  final source = File(
    p.join(
      p.dirname(part.path),
      '${partName.substring(0, partName.length - '.dw.dart'.length)}.dart',
    ),
  );
  if (!source.existsSync()) return true;
  final declaration = RegExp(
    '^\\s*part\\s+[\'"]${RegExp.escape(partName)}[\'"]\\s*;',
    multiLine: true,
  );
  return !declaration.hasMatch(source.readAsStringSync());
}
