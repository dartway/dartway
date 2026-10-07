import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'migration_notes.dart';

/// Verified note dispositions. Neither toolkit provenance nor dependency locks
/// are evidence that a project's code has been migrated. There is no inferred
/// version baseline: an absent record means unconfirmed, even at the target.
class DwMigrationState {
  DwMigrationState._(this.records);

  final Map<String, Map<String, dynamic>> records;

  static File fileIn(Directory root) =>
      File(p.join(root.path, '.dartway', 'migrations.json'));

  static String keyOf(DwMigrationNote note) {
    final packages = note.affects.keys.toList()..sort();
    return jsonEncode([
      note.path,
      {for (final package in packages) package: note.affects[package]},
    ]);
  }

  static DwMigrationState read(Directory root) {
    final file = fileIn(root);
    if (!file.existsSync()) return DwMigrationState._({});
    try {
      final document = jsonDecode(file.readAsStringSync());
      if (document is! Map ||
          document['schema'] != 1 ||
          document['notes'] is! Map) {
        throw const FormatException('expected schema 1 and notes map');
      }
      final records = <String, Map<String, dynamic>>{};
      for (final entry in (document['notes'] as Map).entries) {
        final record = entry.value;
        if (entry.key is! String ||
            record is! Map<String, dynamic> ||
            !['applied', 'not-applicable'].contains(record['disposition']) ||
            record['verification'] is! String ||
            (record['verification'] as String).trim().isEmpty ||
            record['target'] is! String ||
            !RegExp(r'^[a-f0-9]{40}$').hasMatch(record['target'] as String) ||
            record['verifiedAt'] is! String ||
            DateTime.tryParse(record['verifiedAt'] as String) == null ||
            record['path'] is! String ||
            record['affects'] is! Map ||
            (record['affects'] as Map).isEmpty) {
          throw const FormatException('invalid completion record');
        }
        final affects = <String, String>{};
        for (final package in (record['affects'] as Map).entries) {
          if (package.key is! String || package.value is! String) {
            throw const FormatException('invalid package-version metadata');
          }
          Version.parse(package.value as String);
          affects[package.key as String] = package.value as String;
        }
        final note = DwMigrationNote(
          path: record['path'] as String,
          title: '',
          affects: affects,
          body: '',
        );
        if (entry.key != keyOf(note)) {
          throw const FormatException(
            'completion key disagrees with note metadata',
          );
        }
        records[entry.key as String] = record;
      }
      return DwMigrationState._(records);
    } on FormatException catch (error) {
      throw StateError(
        'Cannot read ${file.path}: $error. File left untouched.',
      );
    }
  }

  bool completed(DwMigrationNote note) => records.containsKey(keyOf(note));

  void record(
    DwMigrationNote note, {
    required String disposition,
    required String target,
    required String verification,
  }) {
    records[keyOf(note)] = {
      'path': note.path,
      'affects': note.affects,
      'disposition': disposition,
      'target': target,
      'verification': verification,
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  void write(Directory root) {
    final file = fileIn(root);
    file.parent.createSync(recursive: true);
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'schema': 1, 'notes': records})}\n',
    );
    temporary.renameSync(file.path);
  }
}
