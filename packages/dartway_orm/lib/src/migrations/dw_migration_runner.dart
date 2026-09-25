import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;

import '../db/dw_database_handle.dart';
import 'dw_database_migration.dart';
import 'dw_draft_writer.dart';
import 'dw_migration_checksum.dart';
import 'dw_migration_errors.dart';

/// Applies and rolls back migrations of several namespaces against one
/// database, keeping the set of applied migrations in `dw_migrations`
/// (see `docs/4-server/migrations.md`).
///
/// The migrator owns only the namespaces it is given: ledger rows of other
/// namespaces are neither validated nor touched, so a module's migrations and
/// the application's can be run by different entry points.
final class DwMigrationRunner {
  DwMigrationRunner(
    this._db, {
    required Map<String, List<DwDatabaseMigration>> migrations,
    Map<String, String> sources = const {},
  }) : _migrations = {
         for (final MapEntry(key: namespace, value: list) in migrations.entries)
           namespace: List.unmodifiable(list),
       },
       _sources = Map.unmodifiable(sources);

  /// Where the source files of a namespace's migrations are, by namespace —
  /// for the check that a pending migration is still sealed.
  final Map<String, String> _sources;

  static const ledgerTable = 'dw_migrations';

  /// The session advisory lock serialising migrators across processes:
  /// "dwMigrat" in ASCII.
  static const lockKey = 0x64774d6967726174;

  final DwDatabaseHandle _db;
  final Map<String, List<DwDatabaseMigration>> _migrations;

  /// Applies every pending migration as one batch and returns them in the
  /// order applied.
  ///
  /// Throws [DwMigrationRefused] without applying anything when the ledger
  /// and the code disagree, and [DwMigrationFailed] when a migration throws —
  /// the migrations before it stay applied.
  Future<DwMigrationRun> apply() => _locked((db) async {
    final ledger = await _readLedger(db);
    final registered = _registered();
    _refuseOn([
      ..._checkRegistration(registered, ledger),
      ..._checkLedger(registered, ledger),
    ]);

    final pending = _order([
      for (final migration in registered.values)
        if (!ledger.containsKey(migration.ref)) migration,
    ], satisfied: ledger.keys.toSet());
    if (pending.isEmpty) return const DwMigrationRun(null, []);
    _refuseOn(_checkSealed(pending));

    final batch = (ledger.values.map((row) => row.batch).maxOrNull ?? 0) + 1;
    for (final migration in pending) {
      await _applyOne(db, migration, batch);
    }
    return DwMigrationRun(batch, [
      for (final migration in pending) migration.ref,
    ]);
  });

  /// Pending migrations whose source file, where it is on disk, no longer
  /// matches the checksum it declares.
  List<DwMigrationProblem> _checkSealed(Iterable<_Registered> pending) => [
    for (final entry in pending)
      if (_sources[entry.ref.namespace] case final directory?)
        if (File(p.join(directory, DwDraftWriter.fileName(entry.ref.id)))
            case final file when file.existsSync())
          if (DwMigrationChecksum.declared(file.readAsStringSync())
              case final declared?
              when declared != DwMigrationChecksum.of(file.readAsStringSync()))
            DwUnsealedMigration(entry.ref, path: file.path),
  ];

  /// Rolls back a batch (the last one by default) or a single migration, in
  /// reverse order of application.
  ///
  /// When every migration in the set is transactional the whole rollback is
  /// one transaction: an irreversible migration in the middle leaves the
  /// database exactly as it was.
  Future<DwMigrationRun> rollback({int? batch, DwMigrationRef? id}) {
    if (batch != null && id != null) {
      throw ArgumentError(
        'roll back either a batch or a migration id, not both',
      );
    }
    return _locked((db) async {
      final ledger = await _readLedger(db);
      final registered = _registered();
      _refuseOn(_checkLedger(registered, ledger));

      final List<_LedgerRow> targets;
      if (id != null) {
        final row = ledger[id];
        if (row == null) {
          throw DwMigrationRefused([
            DwRollbackTargetInvalid(id, 'it is not applied'),
          ]);
        }
        targets = [row];
      } else {
        final number = batch ?? ledger.values.map((row) => row.batch).maxOrNull;
        if (number == null) return const DwMigrationRun(null, []);
        targets = [
          for (final row in ledger.values)
            if (row.batch == number) row,
        ];
        if (targets.isEmpty) {
          throw DwMigrationRefused([
            DwRollbackTargetInvalid(
              DwMigrationRef('*', 'batch $number'),
              'no migration was applied in batch $number',
            ),
          ]);
        }
      }

      final targetRefs = {for (final row in targets) row.ref};
      final problems = <DwMigrationProblem>[
        for (final row in targets)
          if (!_migrations.containsKey(row.ref.namespace))
            DwRollbackTargetInvalid(
              row.ref,
              'namespace "${row.ref.namespace}" is not given to this migrator',
            ),
        for (final row in ledger.values)
          if (!targetRefs.contains(row.ref))
            for (final dependency
                in registered[row.ref]?.migration.dependsOn ??
                    const <DwMigrationRef>[])
              if (targetRefs.contains(dependency))
                DwDependentApplied(dependency, row.ref),
      ];
      _refuseOn(problems);

      final ordered = [
        for (final row in targets.sortedBy<num>((row) => -row.seq))
          registered[row.ref]!,
      ];
      if (ordered.every((entry) => entry.migration.transactional)) {
        await db.transaction((tx) async {
          for (final entry in ordered) {
            await _run(
              entry,
              'down',
              () => entry.migration.down(DwMigrationContext(tx)),
            );
            await _deleteRow(tx, entry.ref);
          }
        });
      } else {
        for (final entry in ordered) {
          await _rollbackOne(db, entry);
        }
      }
      return DwMigrationRun(targets.first.batch, [
        for (final entry in ordered) entry.ref,
      ]);
    });
  }

  /// Every registered and every applied migration of the owned namespaces,
  /// without taking the lock or changing anything.
  Future<List<DwMigrationStatus>> status() async {
    final ledger = await _readLedger(_db, create: false);
    final registered = _registered();
    final entries = <DwMigrationStatus>[
      for (final entry in registered.values)
        switch (ledger[entry.ref]) {
          null => DwMigrationStatus(entry.ref, DwMigrationState.pending),
          final row when row.dirty => DwMigrationStatus(
            entry.ref,
            DwMigrationState.dirty,
            batch: row.batch,
            appliedAt: row.appliedAt,
          ),
          final row when !_accepts(entry.migration, row.checksum) =>
            DwMigrationStatus(
              entry.ref,
              DwMigrationState.changed,
              batch: row.batch,
              appliedAt: row.appliedAt,
            ),
          final row => DwMigrationStatus(
            entry.ref,
            DwMigrationState.applied,
            batch: row.batch,
            appliedAt: row.appliedAt,
          ),
        },
      for (final row in ledger.values)
        if (_migrations.containsKey(row.ref.namespace) &&
            !registered.containsKey(row.ref))
          DwMigrationStatus(
            row.ref,
            DwMigrationState.missing,
            batch: row.batch,
            appliedAt: row.appliedAt,
          ),
    ];
    return entries.sorted(
      (a, b) => a.ref.namespace != b.ref.namespace
          ? a.ref.namespace.compareTo(b.ref.namespace)
          : a.ref.id.compareTo(b.ref.id),
    );
  }

  Future<T> _locked<T>(Future<T> Function(DwDatabaseHandle db) body) =>
      _db.pinned((db) async {
        // Waits for a concurrent migrator; everything after this point sees the
        // ledger it left behind.
        await db.run(
          'SELECT pg_advisory_lock(\$1)',
          const [pg.Type.bigInteger],
          const [lockKey],
        );
        try {
          return await body(db);
        } finally {
          await db.run(
            'SELECT pg_advisory_unlock(\$1)',
            const [pg.Type.bigInteger],
            const [lockKey],
          );
        }
      });

  Future<Map<DwMigrationRef, _LedgerRow>> _readLedger(
    DwDatabaseHandle db, {
    bool create = true,
  }) async {
    if (create) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS "$ledgerTable" (
  "namespace" text NOT NULL,
  "id" text NOT NULL,
  "checksum" text NOT NULL,
  "batch" integer NOT NULL,
  "seq" bigserial NOT NULL,
  "state" text NOT NULL CHECK ("state" IN ('applied', 'dirty')),
  "applied_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("namespace", "id")
)''');
    } else {
      final exists = await db.query(
        "SELECT to_regclass('\"$ledgerTable\"') IS NOT NULL AS present",
      );
      if (!exists.first.get<bool>('present')) return const {};
    }
    final rows = await db.query(
      'SELECT "namespace", "id", "checksum", "batch", "seq", "state", "applied_at" '
      'FROM "$ledgerTable" ORDER BY "seq"',
    );
    return {
      for (final row in rows)
        DwMigrationRef(
          row.get<String>('namespace'),
          row.get<String>('id'),
        ): _LedgerRow(
          DwMigrationRef(row.get<String>('namespace'), row.get<String>('id')),
          checksum: row.get<String>('checksum'),
          batch: row.get<int>('batch'),
          seq: row.get<int>('seq'),
          dirty: row.get<String>('state') == 'dirty',
          appliedAt: row.get<DateTime>('applied_at'),
        ),
    };
  }

  Map<DwMigrationRef, _Registered> _registered() {
    final registered = <DwMigrationRef, _Registered>{};
    for (final MapEntry(key: namespace, value: list) in _migrations.entries) {
      for (final migration in list) {
        final ref = DwMigrationRef(namespace, migration.id);
        registered.putIfAbsent(ref, () => _Registered(ref, migration));
      }
    }
    return registered;
  }

  List<DwMigrationProblem> _checkRegistration(
    Map<DwMigrationRef, _Registered> registered,
    Map<DwMigrationRef, _LedgerRow> ledger,
  ) {
    final problems = <DwMigrationProblem>[];
    for (final MapEntry(key: namespace, value: list) in _migrations.entries) {
      final seen = <String>{};
      for (final migration in list) {
        if (!seen.add(migration.id)) {
          problems.add(
            DwDuplicateMigration(DwMigrationRef(namespace, migration.id)),
          );
        }
      }
    }
    for (final entry in registered.values) {
      for (final dependency in entry.migration.dependsOn) {
        if (!registered.containsKey(dependency) &&
            !ledger.containsKey(dependency)) {
          problems.add(DwUnknownDependency(entry.ref, dependency));
        }
      }
    }
    // Depth-first search over registered dependencies; a back edge is a cycle.
    final visiting = <DwMigrationRef>[];
    final done = <DwMigrationRef>{};
    void visit(_Registered entry) {
      if (done.contains(entry.ref)) return;
      final start = visiting.indexOf(entry.ref);
      if (start >= 0) {
        final cycle = [...visiting.sublist(start), entry.ref];
        problems.add(DwDependencyCycle(entry.ref, cycle));
        return;
      }
      visiting.add(entry.ref);
      for (final dependency in entry.migration.dependsOn) {
        if (registered[dependency] case final next?) visit(next);
      }
      visiting.removeLast();
      done.add(entry.ref);
    }

    registered.values.forEach(visit);
    return problems;
  }

  List<DwMigrationProblem> _checkLedger(
    Map<DwMigrationRef, _Registered> registered,
    Map<DwMigrationRef, _LedgerRow> ledger,
  ) {
    DwMigrationProblem? check(_LedgerRow row) {
      if (row.dirty) return DwDirtyMigration(row.ref);
      final entry = registered[row.ref];
      if (entry == null) return DwMissingMigration(row.ref);
      if (!_accepts(entry.migration, row.checksum)) {
        return DwChangedMigration(
          row.ref,
          applied: row.checksum,
          current: entry.migration.checksum,
        );
      }
      return null;
    }

    return [
      for (final row in ledger.values)
        if (_migrations.containsKey(row.ref.namespace)) ?check(row),
    ];
  }

  /// Whether a ledger row sealed with [applied] is [migration] as the code
  /// has it now.
  static bool _accepts(DwDatabaseMigration migration, String applied) =>
      applied == migration.checksum ||
      migration.supersededChecksums.contains(applied);

  void _refuseOn(List<DwMigrationProblem> problems) {
    if (problems.isNotEmpty) throw DwMigrationRefused(problems);
  }

  /// Dependencies first; among migrations free to run, by id, then namespace.
  List<_Registered> _order(
    List<_Registered> pending, {
    required Set<DwMigrationRef> satisfied,
  }) {
    final done = {...satisfied};
    // Namespaces in the order they were given — the framework's, then its
    // modules', then the project's — and by id within one. The framework never
    // references a project's tables and a project references the framework's
    // all the time, so that order holds by construction; ordering by id across
    // namespaces held only while every project migration happened to be newer
    // than the framework migration it relied on.
    final rank = {
      for (final (index, namespace) in _migrations.keys.indexed)
        namespace: index,
    };
    final remaining = pending.sorted(
      (a, b) =>
          switch (rank[a.ref.namespace]!.compareTo(rank[b.ref.namespace]!)) {
            0 => _byId(a, b),
            final byNamespace => byNamespace,
          },
    );
    final ordered = <_Registered>[];
    while (remaining.isNotEmpty) {
      final next = remaining.firstWhere(
        (entry) => entry.migration.dependsOn.every(done.contains),
      );
      remaining.remove(next);
      done.add(next.ref);
      ordered.add(next);
    }
    return ordered;
  }

  static int _byId(_Registered a, _Registered b) {
    final byId = a.ref.id.compareTo(b.ref.id);
    return byId != 0 ? byId : a.ref.namespace.compareTo(b.ref.namespace);
  }

  Future<void> _applyOne(
    DwDatabaseHandle db,
    _Registered entry,
    int batch,
  ) async {
    final migration = entry.migration;
    if (migration.transactional) {
      await db.transaction((tx) async {
        await _run(entry, 'up', () => migration.up(DwMigrationContext(tx)));
        await _insertRow(tx, entry, batch, 'applied');
      });
    } else {
      await _insertRow(db, entry, batch, 'dirty');
      await _run(entry, 'up', () => migration.up(DwMigrationContext(db)));
      await db.execute(
        'UPDATE "$ledgerTable" SET "state" = \'applied\' '
        'WHERE "namespace" = @namespace AND "id" = @id',
        params: {'namespace': entry.ref.namespace, 'id': entry.ref.id},
      );
    }
  }

  Future<void> _rollbackOne(DwDatabaseHandle db, _Registered entry) async {
    final migration = entry.migration;
    if (migration.transactional) {
      await db.transaction((tx) async {
        await _run(entry, 'down', () => migration.down(DwMigrationContext(tx)));
        await _deleteRow(tx, entry.ref);
      });
    } else {
      await db.execute(
        'UPDATE "$ledgerTable" SET "state" = \'dirty\' '
        'WHERE "namespace" = @namespace AND "id" = @id',
        params: {'namespace': entry.ref.namespace, 'id': entry.ref.id},
      );
      await _run(entry, 'down', () => migration.down(DwMigrationContext(db)));
      await _deleteRow(db, entry.ref);
    }
  }

  /// Runs one direction of a migration, turning whatever it throws into
  /// [DwMigrationFailed] with the migration named.
  Future<void> _run(
    _Registered entry,
    String direction,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on DwMigrationException {
      rethrow;
    } catch (error, stackTrace) {
      throw DwMigrationFailed(entry.ref, direction, error, stackTrace);
    }
  }

  Future<void> _insertRow(
    DwDatabaseHandle db,
    _Registered entry,
    int batch,
    String state,
  ) => db.execute(
    'INSERT INTO "$ledgerTable" ("namespace", "id", "checksum", "batch", "state") '
    'VALUES (@namespace, @id, @checksum, @batch, @state)',
    params: {
      'namespace': entry.ref.namespace,
      'id': entry.ref.id,
      'checksum': entry.migration.checksum,
      'batch': batch,
      'state': state,
    },
  );

  Future<void> _deleteRow(
    DwDatabaseHandle db,
    DwMigrationRef ref,
  ) => db.execute(
    'DELETE FROM "$ledgerTable" WHERE "namespace" = @namespace AND "id" = @id',
    params: {'namespace': ref.namespace, 'id': ref.id},
  );
}

/// The outcome of `apply` or `rollback`: the batch and the migrations, in the
/// order they ran. An empty run has no batch.
final class DwMigrationRun {
  const DwMigrationRun(this.batch, this.migrations);

  final int? batch;
  final List<DwMigrationRef> migrations;

  bool get isEmpty => migrations.isEmpty;

  @override
  String toString() => 'DwMigrationRun(batch: $batch, $migrations)';
}

enum DwMigrationState {
  applied,
  pending,

  /// A non-transactional migration started and did not finish.
  dirty,

  /// Applied, and its source changed since.
  changed,

  /// Applied, and no longer registered.
  missing,
}

final class DwMigrationStatus {
  const DwMigrationStatus(this.ref, this.state, {this.batch, this.appliedAt});

  final DwMigrationRef ref;
  final DwMigrationState state;
  final int? batch;
  final DateTime? appliedAt;

  @override
  String toString() =>
      '$ref ${state.name}${batch == null ? '' : ' (batch $batch, $appliedAt)'}';
}

final class _Registered {
  const _Registered(this.ref, this.migration);

  final DwMigrationRef ref;
  final DwDatabaseMigration migration;
}

final class _LedgerRow {
  const _LedgerRow(
    this.ref, {
    required this.checksum,
    required this.batch,
    required this.seq,
    required this.dirty,
    required this.appliedAt,
  });

  final DwMigrationRef ref;
  final String checksum;
  final int batch;
  final int seq;
  final bool dirty;
  final DateTime appliedAt;
}
