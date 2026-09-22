import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../db/dw_postgres_database.dart';
import '../db/dw_database_config.dart';
import '../db/dw_database_handle.dart';
import '../schema/dw_schema_introspector.dart';
import '../schema/dw_database_schema.dart';
import '../schema/dw_schema_diff.dart';
import 'dw_migration_checksum.dart';
import 'dw_draft_writer.dart';
import 'dw_database_migration.dart';
import 'dw_migration_errors.dart';
import 'dw_migration_project.dart';
import 'dw_migration_runner.dart';

/// The migration command line of a project, run from `bin/migrate.dart`:
///
/// ```text
/// apply                          apply pending migrations
/// rollback [--batch N | --id X]  roll back the last batch, a batch, or one migration
/// status                         list applied, pending, dirty, changed and missing
/// create <name>                  write a draft migration from the row classes' schema
/// check                          verify files, schema parity and up/down/up
/// rehash [id ...]                re-seal checksums of edited, unapplied migrations
/// ```
///
/// Exit codes: [exitOk], [exitFailed], [exitRefused], [exitCheckFailed],
/// [exitUsage].
final class DwMigrationCli {
  DwMigrationCli({
    required this.schema,
    required this.migrations,
    required this.directory,
    this.namespace = 'app',
    this.modules = const {},
    this.database,
    this.environment,
    this.scratchDatabasePrefix = 'dw_scratch_',
    DateTime Function()? clock,
    StringSink? out,
  }) : _clock = clock ?? DateTime.now,
       _out = out ?? stdout;

  static const exitOk = 0;

  /// A migration or a database operation failed.
  static const exitFailed = 1;

  /// The ledger and the code disagree; nothing was changed.
  static const exitRefused = 2;

  /// `check` found a difference.
  static const exitCheckFailed = 3;

  static const exitUsage = 64;

  /// The schema the row classes declare.
  final DwDatabaseSchema schema;

  /// The project's migrations, registered in [directory]/migrations.dart.
  final List<DwDatabaseMigration> migrations;

  /// Where migration files live, relative to the working directory.
  final String directory;

  final String namespace;

  /// Migrations of other namespaces (the framework's `dw`, modules) that run
  /// before the project's. Their tables are not part of [schema].
  final Map<String, List<DwDatabaseMigration>> modules;

  /// Defaults to `DW_DATABASE_*` from [environment].
  final DwDatabaseConfig? database;

  /// Where `DW_DATABASE_*` is read from when [database] is not given.
  ///
  /// Defaults to the process environment. A project whose entry points take
  /// their development coordinates from a file passes the environment that
  /// file produced, so `migrate` runs on the same database the server does
  /// without exporting anything.
  final Map<String, String>? environment;

  /// `create` and `check` work on throwaway databases with this prefix.
  final String scratchDatabasePrefix;

  final DateTime Function() _clock;
  final StringSink _out;

  static const _usage = '''
usage: migrate <command>
  apply                          apply pending migrations
  rollback [--batch N | --id X]  roll back the last batch, batch N, or migration X
  status                         list migrations and their state
  create <name>                  write a draft migration for the schema changes
  check                          verify files, schema parity and up/down/up
  rehash [id ...]                re-seal the checksums of edited migrations''';

  /// Runs [args] and returns the exit code, also set as the process
  /// [exitCode].
  Future<int> run(List<String> args) async {
    final code = await _run(args);
    exitCode = code;
    return code;
  }

  Map<String, List<DwDatabaseMigration>> get _allMigrations => {
    ...modules,
    namespace: migrations,
  };

  DwDatabaseConfig get _config =>
      database ??
      DwDatabaseConfig.fromEnvironment(environment ?? Platform.environment);

  Future<int> _run(List<String> args) async {
    if (args.isEmpty) return _usageError('no command given');
    final [command, ...rest] = args;
    try {
      switch (command) {
        case 'apply' when rest.isEmpty:
          return await _apply();
        case 'rollback':
          return await _rollback(rest);
        case 'status' when rest.isEmpty:
          return await _status();
        case 'create' when rest.length == 1:
          return await _create(rest.single);
        case 'check' when rest.isEmpty:
          return await _check();
        case 'rehash':
          return await _rehash(rest);
        default:
          return _usageError('unknown command or arguments: ${args.join(' ')}');
      }
    } on DwMigrationRefused catch (error) {
      _out.writeln(error.message);
      return exitRefused;
    } on DwMigrationFailed catch (error) {
      _out
        ..writeln(error.message)
        ..writeln(error.stackTrace);
      return exitFailed;
    } on _UsageException catch (error) {
      return _usageError(error.message);
    } catch (error, stackTrace) {
      _out
        ..writeln('failed: $error')
        ..writeln(stackTrace);
      return exitFailed;
    }
  }

  int _usageError(String message) {
    _out
      ..writeln(message)
      ..writeln(_usage);
    return exitUsage;
  }

  Future<T> _withDatabase<T>(
    Future<T> Function(DwDatabaseHandle db) body,
  ) async {
    final opened = await DwPostgresDatabase.open(
      _config.copyWith(maxConnections: 2),
    );
    try {
      return await body(opened.db);
    } finally {
      await opened.close();
    }
  }

  Future<int> _apply() => _withDatabase((db) async {
    final run = await DwMigrationRunner(
      db,
      migrations: _allMigrations,
      sources: {namespace: directory},
    ).apply();
    if (run.isEmpty) {
      _out.writeln('nothing to apply');
    } else {
      _out.writeln('applied batch ${run.batch}:');
      for (final ref in run.migrations) {
        _out.writeln('  $ref');
      }
    }
    return exitOk;
  });

  Future<int> _rollback(List<String> args) {
    int? batch;
    DwMigrationRef? id;
    switch (args) {
      case []:
        break;
      case ['--batch', final value]:
        batch = int.tryParse(value);
        if (batch == null) throw _UsageException('--batch takes a number');
      case ['--id', final value]:
        final slash = value.indexOf('/');
        id = slash < 0
            ? DwMigrationRef(namespace, value)
            : DwMigrationRef(
                value.substring(0, slash),
                value.substring(slash + 1),
              );
      default:
        throw _UsageException('rollback takes --batch N or --id X');
    }
    return _withDatabase((db) async {
      final run = await DwMigrationRunner(
        db,
        migrations: _allMigrations,
      ).rollback(batch: batch, id: id);
      if (run.isEmpty) {
        _out.writeln('nothing to roll back');
      } else {
        _out.writeln('rolled back:');
        for (final ref in run.migrations) {
          _out.writeln('  $ref');
        }
      }
      return exitOk;
    });
  }

  Future<int> _status() => _withDatabase((db) async {
    final entries = await DwMigrationRunner(
      db,
      migrations: _allMigrations,
    ).status();
    for (final entry in entries) {
      _out.writeln(entry);
    }
    final problems = entries.where(
      (entry) => switch (entry.state) {
        DwMigrationState.dirty ||
        DwMigrationState.changed ||
        DwMigrationState.missing => true,
        _ => false,
      },
    );
    return problems.isEmpty ? exitOk : exitRefused;
  });

  Future<int> _create(String name) async {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw _UsageException('a migration name is snake_case: [a-z][a-z0-9_]*');
    }
    final changes = await _withScratch((scratch) async {
      final replayed = await _replay(scratch);
      final target = await _canonical(scratch, schema);
      return DwSchemaDiff.compare(from: replayed.schema, to: target.schema);
    });

    final now = _clock().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final id = '${stamp}_$name';
    final className =
        'M${stamp.replaceAll('_', '')}${name.split('_').map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1)).join()}';

    final folder = Directory(directory);
    await folder.create(recursive: true);
    final file = File(p.join(directory, DwDraftWriter.fileName(id)));
    if (file.existsSync()) throw StateError('${file.path} already exists');
    await file.writeAsString(
      DwDraftWriter.migration(
        id: id,
        className: className,
        changes: changes,
        project: DwMigrationProject.of(directory),
      ),
    );
    await _writeRegistration();

    _out.writeln('wrote ${file.path}');
    if (changes.isEmpty) {
      _out.writeln('no schema changes: the migration is empty, for data work');
    }
    for (final change in changes) {
      _out.writeln('  ${change.requiresDecision ? 'DECIDE ' : ''}$change');
    }
    final decisions = changes.where((change) => change.requiresDecision).length;
    if (decisions > 0) {
      _out.writeln(
        '$decisions decision${decisions == 1 ? '' : 's'} required: the draft does '
        'not compile until each decisionRequired(...) is replaced',
      );
    }
    return exitOk;
  }

  Future<void> _writeRegistration() async {
    final files = await _migrationFiles();
    final classes = <String, String>{};
    for (final file in files) {
      classes[file.id] = file.className;
    }
    await File(p.join(directory, 'migrations.dart')).writeAsString(
      DwDraftWriter.registration(
        variable: '${namespace}Migrations',
        classesById: classes,
        project: DwMigrationProject.of(directory),
      ),
    );
  }

  Future<int> _check() async {
    var failed = false;
    void fail(String message) {
      failed = true;
      _out.writeln('FAIL $message');
    }

    // Files: every migration sealed, and registered exactly once.
    final files = await _migrationFiles();
    for (final file in files) {
      if (file.declaredChecksum != file.computedChecksum) {
        fail(
          '${file.path}: the source changed since its checksum was sealed; '
          'if it is not applied anywhere, run `rehash ${file.id}`',
        );
      }
    }
    final fileIds = {for (final file in files) file.id};
    final registeredIds = {for (final migration in migrations) migration.id};
    for (final id in fileIds.difference(registeredIds)) {
      fail('$id has a file but is not registered in migrations.dart');
    }
    for (final id in registeredIds.difference(fileIds)) {
      fail('$id is registered but has no file in $directory');
    }

    await _withScratch((scratch) async {
      final replayed = await _replay(scratch);
      final target = await _canonical(scratch, schema);
      for (final note in {...replayed.unmodelled}) {
        _out.writeln('note: not modelled by row classes: $note');
      }
      final drift = DwSchemaDiff.compare(
        from: replayed.schema,
        to: target.schema,
      );
      if (drift.isEmpty) {
        _out.writeln('ok   migrations produce the row classes\' schema');
      } else {
        fail(
          'migrations do not produce the row classes\' schema; missing changes:',
        );
        for (final change in drift) {
          _out.writeln('       $change');
        }
      }
      if (!await _roundTrip(scratch, replayed.schema, fail)) failed = true;
    });

    return failed ? exitCheckFailed : exitOk;
  }

  /// Rolls the project's migrations back one by one, newest first, then applies
  /// them again one by one, and requires every step up to reproduce the schema
  /// its rollback started from.
  Future<bool> _roundTrip(
    DwPostgresDatabase scratch,
    DwDatabaseSchema full,
    void Function(String message) fail,
  ) async {
    final db = scratch.db;
    final excluded = await _moduleTables(scratch);
    Future<DwDatabaseSchema> snapshot() async =>
        (await DwSchemaIntrospector.read(db, excludeTables: excluded)).schema;

    final applied = await db.query(
      'SELECT "id" FROM "${DwMigrationRunner.ledgerTable}" WHERE "namespace" = @namespace ORDER BY "seq"',
      params: {'namespace': namespace},
    );
    final order = [for (final row in applied) row.get<String>('id')];
    final byId = {for (final migration in migrations) migration.id: migration};

    // before[k]: the schema with the first k migrations applied.
    final before = <int, DwDatabaseSchema>{order.length: full};
    var bottom = order.length;
    for (var k = order.length - 1; k >= 0; k--) {
      try {
        await DwMigrationRunner(
          db,
          migrations: _allMigrations,
        ).rollback(id: DwMigrationRef(namespace, order[k]));
      } on DwMigrationFailed catch (error) {
        if (error.cause is DwIrreversibleMigration) {
          _out.writeln(
            'note: ${order[k]} is irreversible; up/down/up stops there',
          );
          break;
        }
        fail('down of ${order[k]} failed: ${error.cause}');
        return false;
      }
      before[k] = await snapshot();
      bottom = k;
    }

    var ok = true;
    for (var k = bottom; k < order.length; k++) {
      await DwMigrationRunner(
        db,
        migrations: {
          ...modules,
          namespace: [for (final id in order.take(k + 1)) byId[id]!],
        },
      ).apply();
      final after = await snapshot();
      if (after != before[k + 1]) {
        ok = false;
        // before[k + 1] was left by the down of the migration after this one;
        // only the last one compares against the schema all of them produce.
        fail(
          k + 1 < order.length
              ? 'down of ${order[k + 1]} does not restore the schema that '
                    '${order[k]} produces:'
              : 're-applying ${order[k]} does not reproduce the schema:',
        );
        for (final change in DwSchemaDiff.compare(
          from: after,
          to: before[k + 1]!,
        )) {
          _out.writeln('       $change');
        }
      }
    }
    if (ok) {
      _out.writeln(
        'ok   up/down/up of ${order.length - bottom} reversible migration(s)',
      );
    }
    return ok;
  }

  Future<int> _rehash(List<String> ids) async {
    final files = await _migrationFiles();
    final unknown = ids.toSet().difference({for (final file in files) file.id});
    if (unknown.isNotEmpty) {
      throw _UsageException('no migration file for ${unknown.join(', ')}');
    }
    var changed = 0;
    for (final file in files) {
      if (ids.isNotEmpty && !ids.contains(file.id)) continue;
      if (file.declaredChecksum == file.computedChecksum) continue;
      final source = await File(file.path).readAsString();
      await File(file.path).writeAsString(DwMigrationChecksum.seal(source));
      _out.writeln('resealed ${file.id}');
      changed++;
    }
    if (changed == 0) _out.writeln('every checksum already matches its source');
    return exitOk;
  }

  Future<List<_MigrationFile>> _migrationFiles() async {
    final folder = Directory(directory);
    if (!folder.existsSync()) return const [];
    final files = <_MigrationFile>[];
    for (final entity in folder.listSync().whereType<File>().sortedBy(
      (f) => f.path,
    )) {
      final name = p.basename(entity.path);
      if (!name.endsWith('.dart') || name == 'migrations.dart') continue;
      final source = await entity.readAsString();
      final id = DwMigrationChecksum.idOf(source);
      final className = DwMigrationChecksum.classOf(source);
      final declared = DwMigrationChecksum.declared(source);
      if (id == null || className == null || declared == null) {
        throw FormatException(
          '${entity.path} is not a migration: expected a class extending '
          'DwDatabaseMigration with `String get id` and `String get checksum`',
        );
      }
      if (name != DwDraftWriter.fileName(id)) {
        throw FormatException(
          '${entity.path} declares id $id; name the file ${DwDraftWriter.fileName(id)}',
        );
      }
      files.add(
        _MigrationFile(
          entity.path,
          id,
          className,
          declared,
          DwMigrationChecksum.of(source),
        ),
      );
    }
    return files;
  }

  Future<T> _withScratch<T>(
    Future<T> Function(DwPostgresDatabase scratch) body,
  ) async {
    final config = _config;
    final name =
        '$scratchDatabasePrefix${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    final server = await DwPostgresDatabase.open(
      config.copyWith(maxConnections: 1),
    );
    try {
      await server.db.execute('CREATE DATABASE "$name"');
      final scratch = await DwPostgresDatabase.open(
        config.copyWith(name: name, maxConnections: 2),
      );
      try {
        return await body(scratch);
      } finally {
        await scratch.close();
      }
    } finally {
      await server.db.execute('DROP DATABASE IF EXISTS "$name" WITH (FORCE)');
      await server.close();
    }
  }

  /// Applies every migration to a scratch database and reads back the tables
  /// the project owns.
  Future<DwSchemaIntrospection> _replay(DwPostgresDatabase scratch) async {
    if (modules.isNotEmpty) {
      await DwMigrationRunner(scratch.db, migrations: modules).apply();
    }
    final excluded = await _moduleTables(scratch);
    await DwMigrationRunner(scratch.db, migrations: _allMigrations).apply();
    return DwSchemaIntrospector.read(scratch.db, excludeTables: excluded);
  }

  final Expando<Set<String>> _moduleTablesOf = Expando();

  /// Tables that exist before the project's migrations run: the modules' and
  /// the ledger. Computed on the first call, while only they exist.
  Future<Set<String>> _moduleTables(DwPostgresDatabase scratch) async =>
      _moduleTablesOf[scratch] ??= {
        DwMigrationRunner.ledgerTable,
        for (final table in (await DwSchemaIntrospector.read(
          scratch.db,
        )).schema.tables)
          table.name,
      };

  /// The target schema as Postgres itself spells it: created in a separate
  /// schema of the scratch database and introspected, so defaults and types
  /// compare in canonical form rather than as the row class author typed them.
  Future<DwSchemaIntrospection> _canonical(
    DwPostgresDatabase scratch,
    DwDatabaseSchema target,
  ) => scratch.db.pinned((db) async {
    await db.execute(
      'CREATE SCHEMA "dw_target"; SET search_path TO "dw_target", public',
    );
    final m = DwMigrationContext(db);
    // Tables first, foreign keys after: declaration order must not matter.
    for (final table in target.tables) {
      await m.createTable(
        DwTableSchema(
          table.name,
          columns: [
            for (final column in table.columns)
              column.copyWith(references: () => null),
          ],
          indexes: table.indexes,
        ),
      );
    }
    for (final table in target.tables) {
      for (final column in table.columns) {
        if (column.references case final references?) {
          await m.addForeignKey(table.name, column.name, references);
        }
      }
    }
    return DwSchemaIntrospector.read(db, schemaName: 'dw_target');
  });
}

final class _MigrationFile {
  const _MigrationFile(
    this.path,
    this.id,
    this.className,
    this.declaredChecksum,
    this.computedChecksum,
  );

  final String path;
  final String id;
  final String className;
  final String declaredChecksum;
  final String computedChecksum;
}

final class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}
