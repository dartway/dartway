import 'dw_database_migration.dart';

/// Why the migrator refused or failed. Every subtype stops the process: the
/// CLI maps them to non-zero exit codes and the server does not start.
sealed class DwMigrationException implements Exception {
  const DwMigrationException();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The ledger and the code disagree; nothing was applied or rolled back.
/// All problems found are listed at once.
final class DwMigrationRefused extends DwMigrationException {
  DwMigrationRefused(List<DwMigrationProblem> problems)
    : problems = List.unmodifiable(problems);

  final List<DwMigrationProblem> problems;

  @override
  String get message =>
      'refused to migrate:\n${problems.map((problem) => '  - $problem').join('\n')}';
}

/// One inconsistency found before running.
sealed class DwMigrationProblem {
  const DwMigrationProblem(this.ref);

  final DwMigrationRef ref;
}

/// Applied according to the ledger, absent from the code.
final class DwMissingMigration extends DwMigrationProblem {
  const DwMissingMigration(super.ref);

  @override
  String toString() => '$ref is applied but no longer registered in the code';
}

/// Applied with one checksum, registered with another: the source of an
/// applied migration was edited.
final class DwChangedMigration extends DwMigrationProblem {
  const DwChangedMigration(
    super.ref, {
    required this.applied,
    required this.current,
  });

  final String applied;
  final String current;

  @override
  String toString() =>
      '$ref was edited after it was applied (checksum $applied in the ledger, $current in the code)';
}

/// A non-transactional migration that started and never finished.
final class DwDirtyMigration extends DwMigrationProblem {
  const DwDirtyMigration(super.ref);

  @override
  String toString() =>
      '$ref is dirty: a non-transactional migration started and did not finish; '
      'repair the database by hand, then delete its ledger row or mark it applied';
}

/// `dependsOn` names a migration that is not registered.
final class DwUnknownDependency extends DwMigrationProblem {
  const DwUnknownDependency(super.ref, this.dependency);

  final DwMigrationRef dependency;

  @override
  String toString() => '$ref depends on $dependency, which is not registered';
}

/// `dependsOn` forms a cycle.
final class DwDependencyCycle extends DwMigrationProblem {
  const DwDependencyCycle(super.ref, this.cycle);

  final List<DwMigrationRef> cycle;

  @override
  String toString() => 'dependency cycle: ${cycle.join(' -> ')}';
}

/// Two registered migrations share one id in one namespace.
final class DwDuplicateMigration extends DwMigrationProblem {
  const DwDuplicateMigration(super.ref);

  @override
  String toString() => '$ref is registered twice';
}

/// An applied migration outside the rollback set depends on one inside it.
final class DwDependentApplied extends DwMigrationProblem {
  const DwDependentApplied(super.ref, this.dependent);

  final DwMigrationRef dependent;

  @override
  String toString() =>
      'cannot roll back $ref: $dependent is applied and depends on it';
}

/// The rollback target does not exist in the ledger, or belongs to a
/// namespace this migrator was not given.
final class DwRollbackTargetInvalid extends DwMigrationProblem {
  const DwRollbackTargetInvalid(super.ref, this.reason);

  final String reason;

  @override
  String toString() => 'cannot roll back $ref: $reason';
}

/// A migration threw. For a transactional one its transaction was rolled
/// back; a non-transactional one is left `dirty`.
final class DwMigrationFailed extends DwMigrationException {
  const DwMigrationFailed(
    this.ref,
    this.direction,
    this.cause,
    this.stackTrace,
  );

  final DwMigrationRef ref;

  /// `up` or `down`.
  final String direction;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String get message => '$direction of $ref failed: $cause';
}

/// Thrown by `irreversible()`: this migration cannot be rolled back.
final class DwIrreversibleMigration implements Exception {
  const DwIrreversibleMigration();

  @override
  String toString() => 'DwIrreversibleMigration: this migration has no down';
}
