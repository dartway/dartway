import 'dart:io';

import 'package:yaml/yaml.dart';

import 'secret_store.dart';

/// The local `passwords.yaml` that covers every environment.
///
/// Edits are made on the text, not by re-emitting parsed YAML: the file is
/// maintained by hand and its comments explain where each key comes from.
/// Round-tripping through a parser would silently delete them.
class DwMasterPasswordsFile {
  DwMasterPasswordsFile(this.file);

  final File file;

  bool get exists => file.existsSync();

  /// Sections and their key/value pairs, or null when the file is absent.
  Map<String, Map<String, String>>? read() {
    if (!exists) {
      return null;
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw StateError('${file.path} must be a map of sections.');
    }
    final sections = <String, Map<String, String>>{};
    for (final entry in document.entries) {
      final value = entry.value;
      if (value is! YamlMap) {
        continue;
      }
      sections[entry.key.toString()] = {
        for (final pair in value.entries)
          pair.key.toString(): pair.value?.toString() ?? '',
      };
    }
    return sections;
  }

  /// The passwords [environment] actually resolves to.
  ///
  /// Serverpod merges `shared` with the run mode section, the run mode
  /// winning ([PasswordManager.loadPasswordsFromMap]). Comparing sections
  /// separately reports differences that disappear once merged, so anything
  /// that reasons about "what this environment has" flattens first.
  static Map<String, String> effective(
    Map<String, Map<String, String>> sections,
    String environment,
  ) => {...?sections['shared'], ...?sections[environment]};

  /// Writes [values] into their sections, replacing the line of a key that is
  /// already there and inserting the rest after the section header. A section
  /// that does not exist is appended.
  ///
  /// Replacing matters as much as inserting: a key can be present with an
  /// empty value, and appending a second line for it produces a duplicate
  /// mapping key — YAML that no longer parses at all.
  void write(Map<String, Map<String, String>> values) {
    final lines = file.readAsLinesSync();
    final result = <String>[];
    final sectionsSeen = <String>{};
    final written = <String, Set<String>>{};

    final sectionHeader = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*):\s*$');
    final entryLine = RegExp(r'^(\s+)([A-Za-z_][A-Za-z0-9_]*):');

    String? current;

    String encode(String key, String value, String indent) =>
        '$indent$key: ${DwSecretStore.encodeScalar(value)}';

    void flushPending(String section) {
      final pending = values[section];
      if (pending == null) {
        return;
      }
      final done = written.putIfAbsent(section, () => <String>{});
      final missing = pending.entries
          .where((entry) => !done.contains(entry.key))
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
        done.add(entry.key);
        result.add(encode(entry.key, entry.value, '  '));
      }
      result.addAll(trailingBlanks);
    }

    for (final line in lines) {
      final header = sectionHeader.firstMatch(line);
      if (header != null) {
        if (current != null) {
          flushPending(current);
        }
        current = header.group(1)!;
        sectionsSeen.add(current);
        result.add(line);
        continue;
      }

      final entry = current == null ? null : entryLine.firstMatch(line);
      final replacement = entry == null
          ? null
          : values[current]?[entry.group(2)!];
      if (entry != null && replacement != null) {
        written.putIfAbsent(current!, () => <String>{}).add(entry.group(2)!);
        result.add(encode(entry.group(2)!, replacement, entry.group(1)!));
        continue;
      }

      result.add(line);
    }

    if (current != null) {
      flushPending(current);
    }

    for (final section in values.keys) {
      if (sectionsSeen.contains(section) || values[section]!.isEmpty) {
        continue;
      }
      result
        ..add('')
        ..add('$section:');
      for (final entry in values[section]!.entries) {
        result.add(encode(entry.key, entry.value, '  '));
      }
    }

    file.writeAsStringSync('${result.join('\n')}\n');
  }
}
