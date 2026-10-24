// Run from packages/dartway_orm with DW_DATABASE_* set, against Postgres 17.
// Writes timings and full EXPLAIN (ANALYZE, BUFFERS) plans to stdout.
import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';
import '../test/fixtures/relations/generated/dw_schema.dart';
import '../test/support/relation_data.dart';
import '../test/support/test_database.dart';

Future<void> main() async {
  final test = await TestDatabase.create(
    withFixtureSchema: false,
    maxConnections: 1,
  );
  try {
    final db = test.db;
    await createRelationSchema(db);
    final detail = await db.relationDetails.insert(detailDraft('benchmark'));
    stdout.writeln(
      '# ORM relations benchmark\n\nPostgres 17, Docker, warm cache; '
      'median of 7 complete Dart calls, including decoding. Plans use ANALYZE, BUFFERS. '
      'Both batches include the parent find. FK batch filters children by parent ids; '
      'findByIds receives all seeded child ids without discovery (an ideal lower bound). '
      'The flat JOIN returns repeated parent columns. Sequential bound id literals in plans are shortened to first/last/count; all plan nodes, timings and buffers are retained.\n',
    );
    for (final (parents, children, limit) in [
      (1, 200, 1),
      (50, 100, 50),
      (5000, 10, null),
    ]) {
      await db.execute(
        'TRUNCATE relation_parent, relation_child, relation_note RESTART IDENTITY CASCADE; '
        'INSERT INTO relation_parent (detail_id, title, score) SELECT ${detail.id}, '
        "repeat('p', 80), 0 FROM generate_series(1, $parents); "
        'INSERT INTO relation_child (parent_id, rank, note) '
        "SELECT p.id, n, repeat('c', 80) FROM relation_parent p "
        'CROSS JOIN generate_series(1, $children) n; ANALYZE relation_parent; ANALYZE relation_child;',
      );
      Future<Object?> include() => db.relationParents.find(
        include: (t) => [
          t.children.unbounded('benchmark includes the whole seeded child set'),
        ],
        limit: limit,
        unbounded: limit == null ? 'benchmark unbounded case' : null,
      );
      Future<Object?> batch() async {
        final rows = await db.relationParents.find(
          limit: limit,
          unbounded: limit == null ? 'benchmark unbounded case' : null,
        );
        return db.relationChilds.find(
          where: (t) => t.parentId.inList(rows.map((r) => r.id)),
          unbounded: 'benchmark child batch',
        );
      }

      // The seed already knows all child ids. This gives findByIds its
      // ideal baseline without charging an id-discovery query.
      Future<Object?> byIds() async {
        final rows = await db.relationParents.find(
          limit: limit,
          unbounded: limit == null ? 'benchmark unbounded case' : null,
        );
        return db.relationChilds.findByIds(
          List.generate(rows.length * children, (i) => i + 1),
        );
      }

      final flatSql =
          'SELECT p.*, c.* FROM (SELECT * FROM relation_parent'
          '${limit == null ? '' : ' LIMIT @limit:int8'}) p '
          'LEFT JOIN relation_child c ON c.parent_id = p.id';
      Future<Object?> flat() => db.query(flatSql, params: {'limit': ?limit});
      Future<double> median(Future<Object?> Function() run) async {
        await run();
        final samples = <int>[];
        for (var n = 0; n < 7; n++) {
          final timer = Stopwatch()..start();
          await run();
          timer.stop();
          samples.add(timer.elapsedMicroseconds);
        }
        samples.sort();
        return samples[3] / 1000;
      }

      stdout.writeln(
        '## $parents parents × $children children, parent limit ${limit ?? 'none'}\n',
      );
      for (final (label, run) in [
        ('include', include),
        ('FK batch', batch),
        ('findByIds batch', byIds),
        ('flat JOIN', flat),
      ]) {
        stdout.writeln(
          '- $label: ${(await median(run)).toStringAsFixed(3)} ms',
        );
      }
      final statements = await db.query(
        'SELECT name, statement FROM pg_prepared_statements',
      );
      final includeStmt = statements.where((r) {
        final s = r.get<String>('statement');
        return s.startsWith('SELECT "relation_parent".') &&
            s.contains('dw_include_0') &&
            (limit == null ? !s.contains(' LIMIT ') : s.contains(' LIMIT '));
      }).single;
      Future<void> explain(
        String label,
        String statement,
        List<String> args,
      ) async {
        final name = statement.replaceAll('"', '""');
        final plan = await db.query(
          'EXPLAIN (ANALYZE, BUFFERS) EXECUTE "$name"'
          '${args.isEmpty ? '' : '(${args.join(', ')})'}',
        );
        stdout.writeln('\n### $label\n\n```text');
        for (final row in plan) {
          final line = '${row.values.first}'.replaceAllMapped(
            RegExp(r"'\{(\d+(?:,\d+){20,})\}'::bigint\[\]"),
            (match) {
              final ids = match.group(1)!.split(',');
              return "'{${ids.first},...,${ids.last}}'::bigint[] /* ${ids.length} ids */";
            },
          );
          stdout.writeln(line);
        }
        stdout.writeln('```');
      }

      await explain('include', includeStmt.get<String>('name'), [
        if (limit != null) '$limit',
      ]);
      final parentStmt = statements.where((r) {
        final s = r.get<String>('statement');
        return s.startsWith('SELECT "relation_parent".') &&
            !s.contains('dw_include_') &&
            (limit == null ? !s.contains(' LIMIT ') : s.contains(' LIMIT '));
      }).single;
      await explain('batch: parent', parentStmt.get<String>('name'), [
        if (limit != null) '$limit',
      ]);
      final childStmt = statements
          .where(
            (r) =>
                r
                    .get<String>('statement')
                    .startsWith('SELECT "relation_child".') &&
                r.get<String>('statement').contains('parent_id" = ANY'),
          )
          .single;
      await explain('batch: child', childStmt.get<String>('name'), [
        "ARRAY[${List.generate(parents, (i) => i + 1).join(',')}]::bigint[]",
      ]);
      final idsStmt = statements.where((r) {
        final sql = r.get<String>('statement');
        return sql.startsWith('SELECT "relation_child".') &&
            sql.contains('WHERE "id" = ANY');
      }).single;
      await explain('findByIds batch: child', idsStmt.get<String>('name'), [
        "ARRAY[${List.generate(parents * children, (i) => i + 1).join(',')}]::bigint[]",
      ]);
      final flatStmt = statements
          .where(
            (r) =>
                r.get<String>('statement').startsWith('SELECT p.*, c.*') &&
                (limit == null
                    ? !r.get<String>('statement').contains('LIMIT')
                    : r.get<String>('statement').contains('LIMIT')),
          )
          .single;
      await explain('flat JOIN', flatStmt.get<String>('name'), [
        if (limit != null) '$limit',
      ]);
    }
  } finally {
    await test.dispose();
  }
}
