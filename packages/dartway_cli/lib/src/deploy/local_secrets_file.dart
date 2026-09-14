import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The maintainer's copy of every environment's secrets: `deploy/secrets.yaml`,
/// git-ignored, one section per environment.
///
/// ```yaml
/// staging:
///   DW_DATABASE_PASSWORD: '…'
///   SMS_API_TOKEN: '…'
/// ```
///
/// Optional: a project may keep its secrets on the servers alone. When it
/// exists, `secret push` sends a section to its server and `secret pull`
/// brings a server's keys back. There is no shared section — each server holds
/// exactly its own environment, and a key two environments share is written
/// in both, where a reader sees it.
///
/// Edits are made on the text, not by re-emitting parsed YAML: the file is
/// maintained by hand and its comments explain where each key comes from.
/// Round-tripping through a parser would silently delete them.
class DwLocalSecretsFile {
  DwLocalSecretsFile(this.file);

  factory DwLocalSecretsFile.of(Directory projectRoot) =>
      DwLocalSecretsFile(File(p.join(projectRoot.path, relativePath)));

  static const String relativePath = 'deploy/secrets.yaml';

  final File file;

  bool get exists => file.existsSync();

  /// Sections and their key/value pairs, or null when the file is absent.
  Map<String, Map<String, String>>? read() {
    if (!exists) {
      return null;
    }
    final document = loadYaml(file.readAsStringSync());
    if (document == null) {
      return const {};
    }
    if (document is! YamlMap) {
      throw StateError('$relativePath must be a map of environments.');
    }
    final sections = <String, Map<String, String>>{};
    for (final entry in document.entries) {
      final value = entry.value;
      if (value == null) {
        sections[entry.key.toString()] = {};
        continue;
      }
      if (value is! YamlMap) {
        throw StateError(
          '$relativePath: "${entry.key}" must be a map of secret names to '
          'values.',
        );
      }
      sections[entry.key.toString()] = {
        for (final pair in value.entries)
          pair.key.toString(): _scalar(entry.key, pair.key, pair.value),
      };
    }
    return sections;
  }

  /// A secret value is text. A YAML map or list where a value belongs is a
  /// document written unquoted, and turning it into its `toString` would store
  /// something nobody wrote.
  static String _scalar(Object? section, Object? key, Object? value) {
    if (value == null) return '';
    if (value is YamlMap || value is YamlList) {
      throw StateError(
        '$relativePath: $section > $key is not a single value. Quote it, or '
        'store a document with "dartway deploy secret put-file".',
      );
    }
    return value.toString();
  }

  /// Writes [values] into the section of [environment], replacing the line of
  /// a key that is already there and inserting the rest after the section
  /// header. A section that does not exist is appended.
  ///
  /// Replacing matters as much as inserting: a key can be present with an
  /// empty value, and appending a second line for it produces a duplicate
  /// mapping key — YAML that no longer parses at all.
  void write(String environment, Map<String, String> values) {
    final lines = file.readAsLinesSync();
    final result = <String>[];
    final written = <String>{};
    var sectionSeen = false;

    final sectionHeader = RegExp(r'^([A-Za-z0-9_.-]+):\s*$');
    final entryLine = RegExp(r'^(\s+)([A-Za-z_][A-Za-z0-9_]*):');

    String encode(String key, String value, String indent) =>
        "$indent$key: '${value.replaceAll("'", "''")}'";

    String? current;

    void flushPending() {
      final missing = values.entries
          .where((entry) => !written.contains(entry.key))
          .toList();
      if (missing.isEmpty) {
        return;
      }
      // Keep blank lines below the section rather than above the new keys.
      final trailingBlanks = <String>[];
      while (result.isNotEmpty && result.last.trim().isEmpty) {
        trailingBlanks.add(result.removeLast());
      }
      for (final entry in missing) {
        written.add(entry.key);
        result.add(encode(entry.key, entry.value, '  '));
      }
      result.addAll(trailingBlanks);
    }

    for (final line in lines) {
      final header = sectionHeader.firstMatch(line);
      if (header != null) {
        if (current == environment) {
          flushPending();
        }
        current = header.group(1)!;
        if (current == environment) sectionSeen = true;
        result.add(line);
        continue;
      }

      final entry = current == environment ? entryLine.firstMatch(line) : null;
      final replacement = entry == null ? null : values[entry.group(2)!];
      if (entry != null && replacement != null) {
        written.add(entry.group(2)!);
        result.add(encode(entry.group(2)!, replacement, entry.group(1)!));
        continue;
      }

      result.add(line);
    }

    if (current == environment) {
      flushPending();
    }

    if (!sectionSeen && values.isNotEmpty) {
      result
        ..add('')
        ..add('$environment:');
      for (final entry in values.entries) {
        result.add(encode(entry.key, entry.value, '  '));
      }
    }

    file.writeAsStringSync('${result.join('\n')}\n');
  }
}
