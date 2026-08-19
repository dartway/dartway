/// What the migration container said about the schema — and why its exit code
/// is not allowed to answer instead.
///
/// `dartway deploy run` applies migrations by starting the server image once in
/// Serverpod's maintenance role with `--apply-migrations`. Serverpod 3.4.11
/// wraps that whole apply in a `try`/`catch` (`Serverpod._applyMigrations`): a
/// failure sets `verified = false`, and the only consequence of `verified`
/// being false is `if (config.runMode == development) throw ExitException(1)`.
/// Outside development the failure is swallowed. The maintenance role then ends
/// with `throw ExitException(_exitCode)`, and nothing on the failed path ever
/// touches `_exitCode` — so a container that applied nothing exits 0, exactly
/// like one that applied everything.
///
/// The outcome is only ever stated in the text, so the text is what has to be
/// read. These are the literals Serverpod 3.4.11 writes; they are pinned by
/// tests here, and a Serverpod that renames one turns the step [silent] rather
/// than green, which is the safe direction to be wrong in.
library;

/// What became of the schema during one migration step.
enum DwMigrationOutcome {
  /// Migrations were pending and are now applied.
  applied,

  /// Nothing was pending; the schema was already at the latest version.
  alreadyCurrent,

  /// An apply was attempted and threw. The schema is where it was.
  failed,

  /// Nothing threw, and the live database still does not match the target —
  /// Serverpod's own `verifyDatabaseIntegrity` says so.
  drifted,

  /// The project has the migration feature switched off, so the step could not
  /// have done anything.
  disabled,

  /// The container said nothing about the schema at all.
  silent,
}

/// The outcome of one `--apply-migrations` run, read out of its output.
class DwMigrationReport {
  const DwMigrationReport._(this.outcome, this.stated, this.appliedVersions);

  /// Reads [output] — the container's stdout and stderr together, since the
  /// success lines land on one and the failures on the other.
  factory DwMigrationReport.read(String output) {
    final lines = output.split('\n').map((line) => line.trim()).toList();

    final stated = <String>[];
    var failed = false;
    var drifted = false;
    var disabled = false;
    var applied = false;
    var alreadyCurrent = false;
    final versions = <String>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty) {
        continue;
      }

      if (line.contains(_applyFailed) ||
          line.contains(_repairFailed) ||
          line.contains(_versionFailed)) {
        failed = true;
        stated.add(line);
        // `MigrationManager` prints the exception on the line after the
        // version it failed on, and that line is the whole diagnosis — the
        // constraint or relation Postgres refused. Quoting the marker without
        // it hands the reader a stopped deploy and no reason.
        final detail = index + 1 < lines.length ? lines[index + 1] : '';
        if (detail.isNotEmpty &&
            !detail.startsWith('#') &&
            !_isMarker(detail)) {
          stated.add(detail);
        }
        continue;
      }
      if (line.contains(_integrityFailed)) {
        drifted = true;
        stated.add(line);
        continue;
      }
      if (line.contains(_disabled)) {
        disabled = true;
        stated.add(line);
        continue;
      }
      if (line.contains(_alreadyApplied)) {
        alreadyCurrent = true;
        stated.add(line);
        continue;
      }
      if (line.contains(_appliedHeader)) {
        applied = true;
        stated.add(line);
        // Serverpod prints the header, then one ` - <version>` line per
        // migration it ran.
        for (var next = index + 1; next < lines.length; next++) {
          final bullet = lines[next];
          if (!bullet.startsWith('- ')) {
            break;
          }
          versions.add(bullet.substring(2).trim());
        }
        continue;
      }
    }

    // Order matters: a run that applied two migrations and then failed on the
    // third has said both things, and the failure is the one that decides.
    final DwMigrationOutcome outcome;
    if (failed) {
      outcome = DwMigrationOutcome.failed;
    } else if (drifted) {
      outcome = DwMigrationOutcome.drifted;
    } else if (disabled) {
      outcome = DwMigrationOutcome.disabled;
    } else if (applied) {
      outcome = DwMigrationOutcome.applied;
    } else if (alreadyCurrent) {
      outcome = DwMigrationOutcome.alreadyCurrent;
    } else {
      outcome = DwMigrationOutcome.silent;
    }

    return DwMigrationReport._(
      outcome,
      List.unmodifiable(stated),
      List.unmodifiable(versions),
    );
  }

  /// `Serverpod._applyMigrations`, on the catch-all around the whole apply.
  static const String _applyFailed = 'Failed to apply database migrations.';

  /// Same method, when `--apply-repair-migration` found nothing to apply.
  static const String _repairFailed =
      'Failed to apply database repair migration.';

  /// `MigrationManager._migrateToLatestModule`, naming the version that threw.
  static const String _versionFailed = 'Failed to apply migration ';

  /// `MigrationManager.verifyDatabaseIntegrity`, which runs after the apply and
  /// compares the live schema against the target definition table by table.
  static const String _integrityFailed =
      'The database does not match the target database:';

  /// `Serverpod.start`, when the project builds without the migration feature.
  static const String _disabled = 'Migrations are disabled in this project';

  /// `Serverpod._applyMigrations`, when nothing was pending.
  static const String _alreadyApplied =
      'Latest database migration already applied.';

  /// Covers both `Applied database migration:` and its plural.
  static const String _appliedHeader = 'Applied database migration';

  /// Whether [line] is one of the outcome markers, so that a line following a
  /// failure is quoted as its detail only when it is not an outcome of its own.
  static bool _isMarker(String line) =>
      line.contains(_applyFailed) ||
      line.contains(_repairFailed) ||
      line.contains(_versionFailed) ||
      line.contains(_integrityFailed) ||
      line.contains(_disabled) ||
      line.contains(_alreadyApplied) ||
      line.contains(_appliedHeader);

  final DwMigrationOutcome outcome;

  /// The lines that decided [outcome], in the order the container printed them.
  final List<String> stated;

  /// Versions named under an `Applied database migration(s):` header.
  final List<String> appliedVersions;

  /// Whether the schema caught up.
  bool get ok =>
      outcome == DwMigrationOutcome.applied ||
      outcome == DwMigrationOutcome.alreadyCurrent;

  /// Why the step must fail, or null when the schema caught up.
  ///
  /// Every branch names what to run next, because the reader is looking at a
  /// deploy that has just stopped and the useful question is not "what
  /// happened" but "what now".
  String? get failure {
    if (ok) {
      return null;
    }
    final quoted = stated.map((line) => '  $line').join('\n');
    switch (outcome) {
      case DwMigrationOutcome.applied:
      case DwMigrationOutcome.alreadyCurrent:
        return null;
      case DwMigrationOutcome.failed:
        return 'The migration container reported a failure and still exited 0 '
            '— Serverpod only aborts on this in development.\n$quoted\n'
            'The schema is where it was, and every later migration is stuck '
            'behind this one. Services were not restarted, so the running '
            'version is still serving. Read the lines above for the SQL that '
            'threw; a database that has drifted from the migration history is '
            'brought back with "serverpod create-repair-migration" and a '
            'deploy that passes --apply-repair-migration.';
      case DwMigrationOutcome.drifted:
        return 'Nothing threw, and the live schema still does not match what '
            'this build expects.\n$quoted\n'
            'That is the deploy shipping new code against an old schema, which '
            'is the failure this step exists to catch. Either a migration is '
            'missing from the repository — "serverpod create-migration" — or '
            'the database was changed outside the migration history, which '
            '"serverpod create-repair-migration" reconciles.';
      case DwMigrationOutcome.disabled:
        return 'The server image was built without the migration feature, so '
            'this step could not have applied anything.\n$quoted\n'
            'Enable the database feature in the server package, or take the '
            'step out of the deploy deliberately rather than letting it report '
            'work it cannot do.';
      case DwMigrationOutcome.silent:
        return 'The migration container exited 0 without saying anything about '
            'the schema.\n'
            'It should have printed one of "Applied database migration(s):", '
            '"Latest database migration already applied." or "Failed to apply '
            'database migrations." Silence means it never reached the migration '
            'code — a container that died early, an ENTRYPOINT in shell form '
            'that swallowed --apply-migrations (see the "server_entrypoint" '
            'key), or SERVERPOD_SILENCE_LIFECYCLE_MESSAGES=1 in its '
            'environment. Whichever it is, nothing here establishes that the '
            'schema caught up.';
    }
  }

  /// One line for the deploy log on a step that went well.
  String get summary => switch (outcome) {
    DwMigrationOutcome.applied =>
      appliedVersions.isEmpty
          ? 'migrations applied'
          : 'applied: ${appliedVersions.join(', ')}',
    DwMigrationOutcome.alreadyCurrent => 'schema already at the latest version',
    _ => outcome.name,
  };
}
