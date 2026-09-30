import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';

import '../alerts/dw_server_logger.dart';
import '../auth/dw_auth_config.dart';
import '../context/dw_call_context.dart';

/// Work a server does at every start, after its migrations and before it
/// takes a single call.
///
/// The lifecycle is the whole point of the concept, and it is what makes the
/// steps of every project look alike while doing different things:
///
/// - **every start, in every environment.** A step is therefore idempotent by
///   construction — it states what must be true and makes it so, rather than
///   doing something once. What has to happen exactly once per database is a
///   migration, which has a ledger; what a developer applies to a scratch
///   database when they feel like it is a script, and neither belongs here;
/// - **before the port opens.** Nothing has been served when a step runs, so
///   it cannot race a call, and a step that throws stops the start — with the
///   previous version of the server still serving, in a deployment;
/// - **in a background context, in one transaction.** `ctx.db`, `ctx.accounts`
///   and `ctx.files` are the ones a handler has; `ctx.publish` and `ctx.jobs`
///   work and are delivered on commit, and nothing of a step that throws is
///   left behind.
///
/// The first administrator is the case every project has ([DwFirstAdministrator]);
/// rows that must agree with the code — a catalogue, a questionnaire, the
/// reasons a project refuses something — are the other, and have a step of
/// their own, [DwSeedRows]: the next start of every environment converges on
/// the declaration, with no migration to edit afterwards.
///
/// A step is declared on the server (`DwAppServer(startup: …)`) or on the
/// feature it belongs to (`DwServerFeature(startup: …)`); the server's run
/// first, then each feature's, in the order the features are listed.
abstract class DwStartupStep {
  const DwStartupStep();

  /// Named in the log and in the failure that stops the start.
  String get name;

  /// What is wrong with this step's configuration, before anything opens; any
  /// problem refuses startup with the server's own.
  ///
  /// This is where a value read from the environment is judged: a mistyped
  /// administrator is worth a server that does not start, and it is worth
  /// finding out before the database is even opened.
  List<String> problems(DwAuthConfig auth) => const [];

  /// Makes this step's statement true. Says what it did through `ctx.log`,
  /// where a step that changed nothing usually says nothing at all.
  Future<void> run(DwCallContext ctx);
}

/// Brings the administrator the environment names — `DW_ADMIN_IDENTIFIER`,
/// read into `DwServerEnvironment.adminIdentifier` — into existence at every
/// start.
///
/// The admin role is granted by an admin, which leaves the very first one with
/// nowhere to come from. Naming them per environment is that somewhere, and it
/// has no default on purpose: whoever can receive the one-time code on that
/// identifier *is* the administrator, so a value shipped in a template would
/// hand every project that forgot to change it to a stranger.
///
/// The framework goes as far as the account — accounts and identities are its
/// own — and hands it to [grant], which is where the project grants whatever
/// it calls an administrator. Without an [identifier] the step is a warning at
/// every start and nothing else: a server without an admin serves.
///
/// Idempotent, so it acts as a repair as well as a beginning: an identifier
/// demoted in the panel is an administrator again on the next start. That is
/// deliberate — it is the only way back into a project that locked itself out,
/// and the way to stop it is to take the identifier out of the environment.
final class DwFirstAdministrator extends DwStartupStep {
  const DwFirstAdministrator({
    required this.grant,
    required this.identifier,
    this.kindOf = DwIdentifierKind.of,
  });

  /// The phone or e-mail to make an administrator: the server's
  /// `DwServerEnvironment.adminIdentifier`, handed in by `bin/server.dart`
  /// through the project's server factory. `null` or blank for none —
  /// required all the same, so a factory that forgot to pass it does not
  /// compile rather than silently making no administrator.
  final String? identifier;

  /// Which kind of identifier the value is. The default is the framework's
  /// rule, [DwIdentifierKind.of]; a project whose identifiers are neither
  /// replaces it — and its `DwAuthConfig.normalize` has the last word either
  /// way.
  final DwIdentifierKind Function(String identifier) kindOf;

  /// Grants the project's own administrator role to [accountId], in the
  /// step's transaction. Called at every start, so it decides for itself
  /// whether anything is left to do — and says so, if it wants the line.
  final Future<void> Function(DwCallContext ctx, int accountId) grant;

  static const String _variable = 'DW_ADMIN_IDENTIFIER';

  String get _declared => (identifier ?? '').trim();

  @override
  String get name => 'first administrator';

  @override
  List<String> problems(DwAuthConfig auth) {
    final declared = _declared;
    if (declared.isEmpty) return const [];
    final kind = kindOf(declared);
    if (auth.normalize(kind, declared) != null) return const [];
    return [
      '$_variable is not an identifier this project accepts: "$declared" '
          '(read as a ${kind.name})',
    ];
  }

  @override
  Future<void> run(DwCallContext ctx) async {
    final declared = _declared;
    if (declared.isEmpty) {
      ctx.log.warning(
        'no administrator is declared: set $_variable to reach the admin panel',
      );
      return;
    }
    // Created the way a sign-in creates one, so the account, its identifier
    // and the project's profile appear together (`onAccountCreated` runs with
    // a tool origin).
    final (:accountId, :created) = await ctx.accounts.ensure(
      kindOf(declared),
      declared,
    );
    await grant(ctx, accountId);
    ctx.log.info(
      'administrator: $declared (account $accountId'
      '${created ? ', created' : ''})',
    );
  }
}

/// Rows the code declares, which every start writes into the table by their
/// key: a catalogue, a questionnaire, the reasons a project refuses something.
///
/// This is how a project seeds, and the only way: a migration runs once per
/// database, so content put there never reaches a database that applied it
/// before the content changed, and code after `server.start()` runs while
/// calls are already being answered. A seed step runs before the port opens,
/// in a transaction of its own, at every start:
///
/// - a declared row missing from the table is inserted;
/// - a stored row with the same [key] values and other values is written over
///   — an edit of the declaration reaches every environment on its next start;
/// - a stored row that already holds the declared values is not touched, so
///   a start with nothing new writes nothing;
/// - a stored row the declaration does not name is left alone. Retiring a
///   row is a column of its own (`isPublished: false`), declared like any
///   other value, since rows elsewhere may point at it.
///
/// ```dart
/// DwSeedRows(
///   'exercise catalogue',
///   table: ExerciseRow.tableDef,
///   key: (t) => [t.slug],
///   rows: exerciseCatalogue,
/// )
/// ```
///
/// A seed owns its rows: **only rows nobody edits outside the code are a
/// seed** — the next start writes the declaration back over an edit made in
/// an admin panel.
///
/// [key] names the columns a declared row is found by: a natural key, never
/// the `id`, which differs between databases. They must be `NOT NULL` — a
/// conflict never matches a null, so every start would insert the row again —
/// and unique together, by `@DwUniqueColumn` or a unique index. Both, and two
/// declared rows with one key, are refused before the database is opened.
///
/// The rows are constants: a value computed at start (`DateTime.now()`)
/// differs at every start, so the row is rewritten every time. During a
/// rolling deploy the old and the new server both run their declaration
/// against one table, each at its own start: the last to start wins, and a
/// row the new version dropped is left as the old one wrote it. Steps run in
/// the order they are listed, so a seed whose rows point at another seed's
/// comes after it.
final class DwSeedRows<R extends DwTableRow, T extends DwTableDef<R>>
    extends DwStartupStep {
  const DwSeedRows(
    this.name, {
    required this.table,
    required this.key,
    required this.rows,
  });

  @override
  final String name;

  /// The table, as its row class declares it: `ExerciseRow.tableDef`.
  final T table;

  /// The unique, `NOT NULL` columns a declared row is found by.
  final List<DwTableColumn<Object?>> Function(T t) key;

  /// The declared rows, as drafts: the id is the database's, never declared.
  final Iterable<DwRowDraft<R>> rows;

  @override
  List<String> problems(DwAuthConfig auth) {
    final columns = key(table);
    final where = 'seed "$name" (${table.tableName})';
    if (columns.isEmpty) return ['$where: the key names no column'];
    final problems = <String>[
      for (final column in columns)
        if (column.nullable)
          '$where: key column "${column.name}" is nullable — a conflict never '
              'matches a null, and every start would insert the row again',
    ];
    final names = {for (final column in columns) column.name};
    final unique =
        (columns.length == 1 && columns.single.unique) ||
        table.indexSchemas.any(
          (index) =>
              index.unique &&
              index.columns.length == names.length &&
              index.columns.toSet().containsAll(names),
        );
    if (!unique) {
      problems.add(
        '$where: the key (${names.join(', ')}) is not unique — declare '
        '@DwUniqueColumn or a unique index on exactly these columns',
      );
    }
    final seen = <_DwSeedKey>{};
    for (final row in rows) {
      final values = table.toDraftRow(row);
      final key = _DwSeedKey([for (final name in names) values[name]]);
      if (!seen.add(key)) {
        problems.add(
          '$where: two declared rows share the key '
          '(${names.join(', ')}) = (${key.values.join(', ')})',
        );
      }
    }
    return problems;
  }

  @override
  Future<void> run(DwCallContext ctx) async {
    final declared = rows.toList(growable: false);
    final written = await ctx.db
        .repository(table)
        .upsertAll(declared, conflictOn: key);
    if (written > 0) {
      ctx.log.info('seed $name: $written of ${declared.length} rows written');
    }
  }
}

/// The key values of a declared row, compared value by value.
final class _DwSeedKey {
  _DwSeedKey(this.values);

  final List<Object?> values;

  @override
  bool operator ==(Object other) =>
      other is _DwSeedKey &&
      other.values.length == values.length &&
      Iterable.generate(values.length).every(
        (i) => other.values[i] == values[i],
      );

  @override
  int get hashCode => Object.hashAll(values);
}
