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
  /// Every table a deleted account takes with it, each with the way it gets
  /// there: `dw_account → user_profile → team_invitation`.
  ///
  /// Follows `ON DELETE CASCADE` through as many hops as it takes, and says
  /// which hops — because the shape of the path is the question. A table
  /// hanging straight off the account holds that person's own rows; one
  /// reached through their profile is where somebody else's turn up, and a
  /// flat list of names hides exactly that. It also ends an argument that has
  /// no business being had: a reviewer and an author disagreed about how two
  /// tables were connected, and the author was wrong.
  ///
  /// The shortest path per table, framework tables included (their own rows
  /// are supposed to go).
  static Future<List<List<String>>> of(DwDatabaseHandle db) async {
    final rows = await db.query('''
WITH RECURSIVE cascading(rel, path, depth) AS (
  SELECT c.conrelid,
         ARRAY['dw_account', c.conrelid::regclass::text],
         1
    FROM pg_constraint c
   WHERE c.contype = 'f'
     AND c.confdeltype = 'c'
     AND c.confrelid = 'dw_account'::regclass
  UNION ALL
  SELECT c.conrelid,
         cascading.path || c.conrelid::regclass::text,
         cascading.depth + 1
    FROM pg_constraint c
    JOIN cascading ON c.confrelid = cascading.rel
   WHERE c.contype = 'f'
     AND c.confdeltype = 'c'
     AND cascading.depth < 20
     -- A table reached twice is a loop, and a loop adds no table.
     AND NOT (c.conrelid::regclass::text = ANY (cascading.path))
)
SELECT DISTINCT ON (rel) path FROM cascading
 ORDER BY rel, array_length(path, 1), path
''');
    final paths = [
      for (final row in rows) row.get<List<Object?>>('path').cast<String>(),
    ];
    paths.sort((a, b) => a.last.compareTo(b.last));
    return paths;
  }

  /// Of [paths], the ones ending in a table of the project rather than of the
  /// framework or one of its modules.
  static List<List<String>> projectOnesOf(Iterable<List<String>> paths) => [
    for (final path in paths)
      if (!path.last.startsWith('dw_')) path,
  ];

  /// `dw_account → user_profile → team_invitation`.
  static String _arrows(List<String> path) => path.join(' → ');

  /// What to refuse to start with, when the project has cascading rows and
  /// has not said what deleting an account should do with them.
  ///
  /// It names the fact — these tables go — and never the conclusion — you
  /// forgot to tell somebody. What is told, and to whom, is the project's:
  /// one project publishes to an admin channel, the next enqueues a webhook,
  /// and a framework that guessed would be wrong in half of them within a
  /// year. What it does say is that the tool is there: the hook is inside the
  /// deleting transaction, so publishing and enqueueing from it are possible
  /// at all — which is the question somebody reading the list asks next.
  static String complaintFor(List<List<String>> paths) =>
      'deleting an account would also delete '
      '${paths.map((path) => path.last).join(', ')}, and '
      'DwAuthConfig.onAccountDeleting is not set.\n'
      '${paths.map((path) => '  ${_arrows(path)}').join('\n')}\n'
      'DwDeleteMyAccount is part of every server: these rows are already '
      'reachable by the person they are about.\n'
      'Decide once, in DwAuthConfig:\n'
      '  - onAccountDeleting: delete what is about that person alone, and '
      'keep what someone else holds on to by emptying the profile instead '
      '(a tombstone — see docs/4-server/auth-identity.md);\n'
      '  - or refuse deletion there (ctx.refuse(...)) while the project has '
      'not decided — honest, and reversible;\n'
      '  - or declare the hook empty, with a comment saying these rows are '
      'meant to go.\n'
      'The hook runs inside the transaction that deletes the account: '
      'ctx.publish and ctx.jobs work from there, so whatever has to be told '
      'about the person leaving is told in the same transaction, or not at '
      'all.';

  /// What to say on every start when deletion does take project rows with
  /// it — the hook exists, and this is what it is dealing with.
  static String noticeFor(List<List<String>> paths) =>
      'deleting an account also deletes '
      '(onAccountDeleting runs in that transaction; ctx.publish and ctx.jobs '
      'work from there):\n'
      '${paths.map((path) => '  ${_arrows(path)}').join('\n')}';
}
