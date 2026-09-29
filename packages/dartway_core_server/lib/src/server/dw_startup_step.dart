import 'dart:io';

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

/// Brings the administrator named by an environment variable into existence at
/// every start.
///
/// The admin role is granted by an admin, which leaves the very first one with
/// nowhere to come from. Naming them per environment is that somewhere, and it
/// has no default on purpose: whoever can receive the one-time code on that
/// identifier *is* the administrator, so a value shipped in a template would
/// hand every project that forgot to change it to a stranger.
///
/// The framework goes as far as the account — accounts and identities are its
/// own — and hands it to [grant], which is where the project grants whatever
/// it calls an administrator. Unset, the variable is a warning at every start
/// and nothing else: a server without an admin serves.
///
/// Idempotent, so it acts as a repair as well as a beginning: an identifier
/// demoted in the panel is an administrator again on the next start. That is
/// deliberate — it is the only way back into a project that locked itself out,
/// and the way to stop it is to take the identifier out of the environment.
final class DwFirstAdministrator extends DwStartupStep {
  const DwFirstAdministrator({
    required this.grant,
    this.variable = defaultVariable,
    this.kindOf = DwIdentifierKind.of,
    Map<String, String>? environment,
  }) : _environment = environment;

  /// The variable every project uses unless it says otherwise. One name across
  /// projects is the point: the secret store, `deploy/config.yaml` and this
  /// documentation all mean the same line.
  static const String defaultVariable = 'DW_ADMIN_IDENTIFIER';

  final String variable;

  /// Which kind of identifier the value is. The default is the framework's
  /// rule, [DwIdentifierKind.of]; a project whose identifiers are neither
  /// replaces it — and its `DwAuthConfig.normalize` has the last word either
  /// way.
  final DwIdentifierKind Function(String identifier) kindOf;

  /// Grants the project's own administrator role to [accountId], in the
  /// step's transaction. Called at every start, so it decides for itself
  /// whether anything is left to do — and says so, if it wants the line.
  final Future<void> Function(DwCallContext ctx, int accountId) grant;

  final Map<String, String>? _environment;

  Map<String, String> get _values => _environment ?? Platform.environment;

  String get _declared => (_values[variable] ?? '').trim();

  @override
  String get name => 'first administrator';

  @override
  List<String> problems(DwAuthConfig auth) {
    final declared = _declared;
    if (declared.isEmpty) return const [];
    final kind = kindOf(declared);
    if (auth.normalize(kind, declared) != null) return const [];
    return [
      '$variable is not an identifier this project accepts: "$declared" '
          '(read as a ${kind.name})',
    ];
  }

  @override
  Future<void> run(DwCallContext ctx) async {
    final declared = _declared;
    if (declared.isEmpty) {
      ctx.log.warning(
        'no administrator is declared: set $variable to reach the admin panel',
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
/// in the start's transaction, at every start:
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
///   table: (db) => db.exercises,
///   key: (t) => [t.slug],
///   rows: exerciseCatalogue,
/// )
/// ```
///
/// [key] names unique columns — the natural key a person would use, never
/// the `id`, which differs between databases. The rows are the rows as
/// declared, without ids. Steps run in the order they are listed, so a seed
/// whose rows point at another seed's comes after it.
///
/// Rows an administrator edits afterwards are not a seed: the next start
/// would write the declaration back over the edit.
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

  /// The table, as the project's generated repository: `(db) => db.exercises`.
  final DwTableRepository<R, T> Function(DwDatabaseHandle db) table;

  /// The unique columns a declared row is found by.
  final List<DwTableColumn<Object?>> Function(T t) key;

  final Iterable<R> rows;

  @override
  Future<void> run(DwCallContext ctx) async {
    final declared = rows.toList(growable: false);
    final written = await table(ctx.db).upsertAll(declared, conflictOn: key);
    if (written > 0) {
      ctx.log.info('seed $name: $written of ${declared.length} rows written');
    }
  }
}
