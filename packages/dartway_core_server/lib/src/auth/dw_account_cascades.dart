import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

/// What deleting an account takes with it, read from the database itself.
///
/// `DwDeleteMyAccount` is part of every server. A project that pointed its own
/// rows at `dw_account` with `ON DELETE CASCADE` — the obvious way to write
/// that foreign key, and what a generated one does — has therefore made those
/// rows deletable from outside, by the person they are about, from the moment
/// its framework pin moved. Nothing in the project changed, nothing failed to
/// compile, and no test went red.
///
/// It happened: a project's profiles and every survey answer behind them went
/// on the first deletion of a stand account. It was found by reading the
/// framework's commits, not by anything the project could run.
///
/// So the server reads its own foreign keys at startup and says what would go
/// — by name, transitively, because the row that hurts is usually not the one
/// that names `dw_account` but the one hanging off it.
@internal
abstract final class DwAccountCascades {
  /// Every table a deleted account takes with it, in order, framework tables
  /// included (their own rows are supposed to go).
  ///
  /// Follows `ON DELETE CASCADE` through as many hops as it takes: a profile
  /// off the account, an answer off the profile, a file off the answer.
  static Future<List<String>> of(DwDatabaseHandle db) async {
    final rows = await db.query('''
WITH RECURSIVE cascading(rel, depth) AS (
  SELECT c.conrelid, 1
    FROM pg_constraint c
   WHERE c.contype = 'f'
     AND c.confdeltype = 'c'
     AND c.confrelid = 'dw_account'::regclass
  UNION
  SELECT c.conrelid, cascading.depth + 1
    FROM pg_constraint c
    JOIN cascading ON c.confrelid = cascading.rel
   WHERE c.contype = 'f'
     AND c.confdeltype = 'c'
     AND cascading.depth < 20
)
SELECT DISTINCT rel::regclass::text AS name FROM cascading ORDER BY 1
''');
    return [for (final row in rows) row.get<String>('name')];
  }

  /// Of [tables], the ones that belong to the project rather than to the
  /// framework or one of its modules.
  static List<String> projectOnesOf(Iterable<String> tables) => [
    for (final table in tables)
      if (!table.startsWith('dw_')) table,
  ];

  /// What to refuse to start with, when the project has cascading rows and
  /// has not said what deleting an account should do with them.
  static String complaintFor(List<String> tables) =>
      'deleting an account would also delete ${tables.join(', ')}, and '
      'DwAuthConfig.onAccountDeleting is not set.\n'
      'DwDeleteMyAccount is part of every server: these rows are already '
      'reachable by the person they are about.\n'
      'Decide once, in DwAuthConfig:\n'
      '  - onAccountDeleting: delete what is about that person alone, and '
      'keep what someone else holds on to by emptying the profile instead '
      '(a tombstone — see docs/4-server/auth-identity.md);\n'
      '  - or refuse deletion there (ctx.refuse(...)) while the project has '
      'not decided — honest, and reversible;\n'
      '  - or declare the hook empty, with a comment saying these rows are '
      'meant to go.';

  /// What to say on every start when deletion does take project rows with
  /// it — the hook exists, and this is what it is dealing with.
  static String noticeFor(List<String> tables) =>
      'deleting an account also deletes: ${tables.join(', ')}';
}
