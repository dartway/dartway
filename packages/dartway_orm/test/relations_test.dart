import 'dart:async';
import 'dart:typed_data';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/relations/relation_rows.dart';
import 'fixtures/relations/generated/dw_schema.dart';
import 'support/test_database.dart';
import 'support/relation_data.dart';

void main() {
  final database = useTestDatabase(
    withFixtureSchema: false,
    countRoundTrips: true,
    maxConnections: 1,
  );
  DwDatabaseHandle db() => database().db;
  const parentTable = RelationParentRow.tableDef;
  late List<RelationParentRow> parents;

  setUpAll(() => createRelationSchema(db()));
  setUp(() async {
    await db().execute(
      'TRUNCATE relation_detail, relation_parent, relation_child, relation_note RESTART IDENTITY CASCADE',
    );
    parents = await seedRelations(db());
  });

  test(
    'two to-one, two to-many, depth three, filter/order: exactly one statement',
    () async {
      Future<List<RelationParentRow>> read() => db().relationParents.find(
        where: (t) => t.detail.ancestor.ancestor.label.equals('top'),
        orderBy: (t) => [t.detail.label.desc(), t.id.asc()],
        limit: 3,
        offset: 1,
        include: (t) => [
          t.detail.include(
            (d) => [
              d.ancestor.include((a) => [a.ancestor]),
            ],
          ),
          t.optionalDetail,
          t.children.take(
            2,
            orderBy: (c) => [c.rank.desc()],
            include: (c) => [
              c.parent.include((p) => [p.detail]),
            ],
          ),
          t.notes.unbounded('fixture notes per parent'),
        ],
      );
      // The first execution prepares the shape once, as for every ORM call.
      final statements = database().database.completedStatements;
      final cold = database().database.roundTrips;
      await read();
      expect(database().database.roundTrips - cold, 2);
      expect(database().database.completedStatements - statements, 1);
      final before = database().database.roundTrips;
      final rows = await read();
      expect(database().database.roundTrips - before, 1);
      expect(rows.map((r) => r.id), [
        parents[3].id,
        parents[0].id,
        parents[2].id,
      ]);
      expect(rows.map((r) => r.many(parentTable.children).length), [1, 2, 2]);
      expect(rows.map((r) => r.many(parentTable.notes).length), [3, 2, 1]);
      expect(rows[1].many(parentTable.children).map((r) => r.rank), [3, 2]);
      final statementsSql = await db().query(
        'SELECT statement FROM pg_prepared_statements',
      );
      final statement = statementsSql
          .map((r) => r.get<String>('statement'))
          .singleWhere(
            (sql) =>
                sql.startsWith('SELECT "relation_parent".') &&
                sql.contains('"dw_include_3"'),
          );
      // The include, filter and order share the same forward paths.
      expect('LEFT JOIN "relation_detail"'.allMatches(statement).length, 5);
      final nestedChild = rows.first.many(parentTable.children).single;
      expect(
        nestedChild
            .one(RelationChildRow.tableDef.parent)
            .one(parentTable.detail)
            .label,
        'b',
      );
      final detail = rows.first.one(parentTable.detail);
      final mid = detail.one(RelationDetailRow.tableDef.ancestor)!;
      expect(mid.one(RelationDetailRow.tableDef.ancestor)!.label, 'top');
      expect(rows.first.one(parentTable.optionalDetail), isNull);
    },
  );

  test(
    'findFirst and findById include, nullable and missing, no implicit loading',
    () async {
      final row = (await db().relationParents.findById(
        parents[1].id,
        include: (t) => [t.optionalDetail, t.children.take(1)],
      ))!;
      final RelationDetailRow? detail = row.one(parentTable.optionalDetail);
      expect(detail!.label, 'a');
      expect(row.many(parentTable.children), isEmpty);
      expect(() => row.one(parentTable.detail), throwsStateError);
      expect(() => parents.first.many(parentTable.children), throwsStateError);
      expect(
        await db().relationParents.findById(-1, include: (t) => [t.detail]),
        isNull,
      );
      final first = (await db().relationParents.findFirst(
        orderBy: (t) => [t.id.asc()],
        include: (t) => [t.detail],
      ))!;
      expect(first.id, parents.first.id);
      expect(first.one(parentTable.detail).label, 'a');
    },
  );

  test(
    'each column carrier round-trips in to-one and JSON-aggregated to-many',
    () async {
      final plain = (await db().relationDetails.findById(
        parents.first.detailId,
      ))!;
      final parent = (await db().relationParents.findById(
        parents.first.id,
        include: (t) => [t.detail],
      ))!;
      expect(parent.one(parentTable.detail), plain);
      expect(plain.integerValue, 9223372036854775806);
      expect(plain.instant, DateTime.utc(2026, 10, 22, 9, 34, 56, 123, 456));
      expect(plain.day, DwCalendarDay(1, 1, 1));
      expect(plain.bytes, [0, 1, 127, 128, 255]);
      final mid = (await db().relationDetails.findById(
        plain.ancestorId!,
        include: (t) => [
          t.descendants.take(20, orderBy: (d) => [d.id.asc()]),
        ],
      ))!;
      expect(mid.many(RelationDetailRow.tableDef.descendants).first, plain);
      final full = await db().relationDetails.insert(
        detailDraft('full').copyWith(
          optionalText: const DwSetField(''),
          optionalDay: DwSetField(DwCalendarDay(9999, 12, 31)),
          optionalInstant: DwSetField(
            DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999),
          ),
          optionalBytes: DwSetField(Uint8List(0)),
          optionalDouble: const DwSetField(double.infinity),
        ),
      );
      await db().relationDetails.transition(
        full.id,
        column: (t) => t.state,
        to: DetailState.ready,
      );
      await db().relationParents.update(
        parents.first.copyWith(detailId: full.id),
      );
      final loaded = (await db().relationParents.findById(
        parents.first.id,
        include: (t) => [t.detail],
      ))!.one(parentTable.detail);
      expect(loaded, await db().relationDetails.findById(full.id));
      expect(loaded.state, DetailState.ready);
      expect(loaded.optionalDouble, double.infinity);
      expect(loaded.optionalInstant!.microsecondsSinceEpoch, -1);
    },
  );

  test(
    'findFirstPer decodes projected related keys, including shared names',
    () async {
      final byId = await db().relationParents.findFirstPer(
        (t) => t.detail.id,
        orderBy: (t) => [t.id.asc()],
      );
      expect(byId.keys.toSet(), {parents[0].detailId, parents[1].detailId});
      expect(byId[parents[0].detailId]!.id, parents[0].id);
      final byLabel = await db().relationParents.findFirstPer(
        (t) => t.detail.label,
        orderBy: (t) => [t.id.asc()],
      );
      expect(byLabel.map((k, v) => MapEntry(k, v.id)), {
        'a': parents[0].id,
        'b': parents[1].id,
      });
    },
  );

  test('findFirstPer projection cannot shadow a root dw_key column', () async {
    await db().execute(
      'ALTER TABLE relation_parent ADD COLUMN dw_key bigint NOT NULL DEFAULT 999',
    );
    addTearDown(
      () => db().execute('ALTER TABLE relation_parent DROP COLUMN dw_key'),
    );
    final grouped = await db()
        .repository<RelationParentRow, _ProjectionTable>(
          const _ProjectionTable(),
        )
        .findFirstPer((t) => t.id, orderBy: (t) => [t.id.asc()]);
    expect(grouped.keys.toSet(), parents.map((p) => p.id).toSet());
    expect(grouped.values.map((p) => p.title), parents.map((p) => p.title));
  });

  test('related mutation conjunctions reuse a shared join', () async {
    expect(
      await db().relationParents.updateWhere(
        where: (t) =>
            t.detail.label.equals('a') &
            t.detail.integerValue.gt(0) &
            t.id.gt(0),
        set: (t) => [t.score.set(5)],
      ),
      2,
    );
    final statements = await db().query(
      "SELECT statement FROM pg_prepared_statements WHERE statement LIKE 'UPDATE \"relation_parent\" SET%' AND statement LIKE '%integer_value%'",
    );
    expect(statements, hasLength(1));
    expect(
      'LEFT JOIN "relation_detail"'.allMatches(
        statements.single.get<String>('statement'),
      ),
      hasLength(1),
    );
  });

  test(
    'nullable related keys retain the NULL group in grouped reads',
    () async {
      expect(
        await db().relationParents.countBy((t) => t.optionalDetail.label),
        {null: 3, 'a': 1},
      );
      expect(
        await db().relationParents.sumBy(
          (t) => t.optionalDetail.label,
          (t) => t.score,
        ),
        {null: 0, 'a': 0},
      );
      expect(
        await db().relationParents.maxBy(
          (t) => t.optionalDetail.label,
          (t) => t.id,
        ),
        {null: parents[3].id, 'a': parents[1].id},
      );
      final first = await db().relationParents.findFirstPer(
        (t) => t.optionalDetail.label,
        orderBy: (t) => [t.id.asc()],
      );
      expect(first.map((k, v) => MapEntry(k, v.id)), {
        null: parents[0].id,
        'a': parents[1].id,
      });
      expect(
        await db().relationParents.maxBy(
          (t) => t.title,
          (t) => t.optionalDetail.id,
        ),
        {'one': parents[1].optionalDetailId},
      );
    },
  );

  test(
    'related mutations recheck root guards after waiting for a lock',
    () async {
      final other = await database().openAnother();
      addTearDown(other.close);
      for (final operation in ['transition', 'update', 'delete']) {
        final row = await db().relationDetails.insert(
          detailDraft(operation, ancestorId: 1),
        );
        final locked = Completer<void>();
        final release = Completer<void>();
        final first = db().transaction((tx) async {
          await tx.relationDetails.transition(
            row.id,
            column: (t) => t.state,
            to: DetailState.ready,
          );
          locked.complete();
          await release.future;
        });
        await locked.future;
        final pending = switch (operation) {
          'transition' =>
            other.db.relationDetails
                .transitionWhere(
                  where: (t) =>
                      t.id.equals(row.id) & t.ancestor.label.equals('top'),
                  column: (t) => t.state,
                  to: DetailState.ready,
                )
                .then((rows) => rows.length),
          'update' => other.db.relationDetails.updateWhere(
            where: (t) =>
                t.id.equals(row.id) &
                t.state.equals(DetailState.fresh) &
                t.ancestor.label.equals('top'),
            set: (t) => [t.label.set('lost guard')],
          ),
          _ => other.db.relationDetails.deleteWhere(
            where: (t) =>
                t.id.equals(row.id) &
                t.state.equals(DetailState.fresh) &
                t.ancestor.label.equals('top'),
          ),
        };
        try {
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (true) {
            final waiting = await other.db.query(
              "SELECT 1 FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock' AND query LIKE '%relation_detail%'",
            );
            if (waiting.isNotEmpty) break;
            if (DateTime.now().isAfter(deadline)) {
              fail('competing mutation did not wait for the row lock');
            }
          }
        } finally {
          release.complete();
          await first;
        }
        expect(await pending, 0, reason: operation);
        final stored = (await db().relationDetails.findById(row.id))!;
        expect(stored.state, DetailState.ready);
        expect(stored.label, operation);
      }
    },
  );

  test(
    'take defaults to primary-key order and aggregates with explicit order',
    () async {
      final row = (await db().relationParents.findById(
        parents.first.id,
        include: (t) => [t.children.take(2)],
      ))!;
      expect(row.many(parentTable.children).map((c) => c.rank), [1, 2]);
      final sql = await db().query(
        "SELECT statement FROM pg_prepared_statements WHERE statement LIKE '%json_agg(\"dw_row\"%' AND statement NOT LIKE '%pg_prepared_statements%'",
      );
      expect(sql, isNotEmpty);
      expect(
        sql.any(
          (r) => r
              .get<String>('statement')
              .contains('ORDER BY "dw_rel_1"."id" LIMIT'),
        ),
        isTrue,
      );
      for (final statement in sql) {
        expect(
          statement.get<String>('statement'),
          contains('json_agg("dw_row" ORDER BY'),
        );
      }
    },
  );

  test(
    'pathless conflict targets refuse related columns before executing SQL',
    () async {
      await expectLater(
        db().relationParents.upsert(
          NewRelationParentRow(detailId: parents.first.detailId, title: 'bad'),
          conflictOn: (t) => [t.detail.id],
        ),
        throwsArgumentError,
      );
      await expectLater(
        db().relationParents.upsertAll([
          NewRelationParentRow(detailId: parents.first.detailId, title: 'bad'),
        ], conflictOn: (t) => [t.detail.id]),
        throwsArgumentError,
      );
      await expectLater(
        db().relationParents.tryInsert(
          NewRelationParentRow(detailId: parents.first.detailId, title: 'bad'),
          onConflict: DwOnConflict.doNothing((t) => [t.detail.id]),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'exceptional date carriers match plain reads or refuse with DwDecodeException',
    () async {
      for (final (column, value) in [
        ('instant', 'infinity'),
        ('instant', '-infinity'),
        ('day', 'infinity'),
        ('day', '-infinity'),
        ('day', '0001-01-01 BC'),
      ]) {
        await db().execute(
          "UPDATE relation_detail SET $column = '$value' WHERE id = ${parents.first.detailId}",
        );
        // PostgreSQL's binary driver cannot represent timestamp infinity;
        // includes must refuse it at the ORM decode boundary instead.
        await expectLater(
          db().relationParents.findById(
            parents.first.id,
            include: (t) => [t.detail],
          ),
          throwsA(isA<DwDecodeException>()),
        );
        await db().execute(
          "UPDATE relation_detail SET instant = '2026-10-22T00:00:00Z', day = '0001-01-01' WHERE id = ${parents.first.detailId}",
        );
      }
    },
  );

  final cases =
      <(String, DwWhereCondition Function(RelationParentTable), List<int>)>[
        ('any', (t) => t.children.any((c) => c.rank.gte(2)), [0, 2]),
        ('none', (t) => t.children.none((c) => c.rank.gte(2)), [1, 3]),
        ('every', (t) => t.children.every((c) => c.rank.gte(2)), [1, 2]),
        (
          'every nullable predicate',
          (t) => t.children.every((c) => c.note.equals('ok')),
          [1, 2],
        ),
        (
          'count',
          (t) => t.children.count(where: (c) => c.rank.gte(2)).equals(2),
          [0, 2],
        ),
        (
          'count range',
          (t) => t.children.count().gt(1) & t.children.count().lte(3),
          [0, 2],
        ),
        (
          'chained to-one',
          (t) =>
              t.detail.ancestor.ancestor.label.equals('top') &
              t.detail.label.equals('a'),
          [0, 2],
        ),
        (
          'reverse then to-one',
          (t) => t.children.any((c) => c.parent.detail.label.equals('b')),
          [3],
        ),
        ('nullable to-one', (t) => t.optionalDetail.label.equals('a'), [1]),
        (
          'mixed OR',
          (t) => t.title.equals('one') | t.detail.label.equals('a'),
          [0, 1, 2],
        ),
        (
          'negated mixed OR',
          (t) => (t.optionalDetail.label.equals('a') | t.title.equals('three'))
              .not(),
          [0, 2],
        ),
        (
          'related OR',
          (t) =>
              t.optionalDetail.label.equals('a') | t.detail.label.equals('a'),
          [0, 1, 2],
        ),
        (
          'negated related',
          (t) => t.optionalDetail.label.equals('a').not(),
          [0, 2, 3],
        ),
      ];
  for (final (name, where, indexes) in cases) {
    test(
      '$name works on finds, counts, exists, updates and aggregates',
      () async {
        final ids = [for (final i in indexes) parents[i].id];
        expect(
          (await db().relationParents.find(
            where: where,
            orderBy: (t) => [t.id.asc()],
            unbounded: 'fixture',
          )).map((r) => r.id),
          ids,
        );
        expect(await db().relationParents.count(where: where), ids.length);
        expect(await db().relationParents.exists(where: where), ids.isNotEmpty);
        expect(
          await db().relationParents.updateWhere(
            where: where,
            set: (t) => [t.score.set(7)],
          ),
          ids.length,
        );
        expect(
          await db().relationParents.sum((t) => t.score, where: where),
          7 * ids.length,
        );
        expect(
          await db().relationParents.max((t) => t.id, where: where),
          ids.isEmpty ? null : ids.last,
        );
        expect(
          await db().relationParents.countBy(
            (t) => t.detail.label,
            where: where,
          ),
          {
            for (final label in ['a', 'b'])
              if (indexes.any((i) => (i.isEven ? 'a' : 'b') == label))
                label: indexes
                    .where((i) => (i.isEven ? 'a' : 'b') == label)
                    .length,
          },
        );
        expect(
          await db().relationParents.exists(
            where: (t) => where(t) & t.id.equals(-1),
          ),
          isFalse,
        );
      },
    );
  }

  test(
    'unbounded parents use independent grouped collections, including empty sets',
    () async {
      final rows = await db().relationParents.find(
        orderBy: (t) => [t.id.asc()],
        unbounded: 'fixture',
        include: (t) => [
          t.children.unbounded(
            'fixture',
            orderBy: (c) => [c.rank.desc()],
            where: (c) => c.rank.gte(2),
          ),
          t.notes.unbounded('fixture', orderBy: (n) => [n.id.asc()]),
        ],
      );
      expect(rows.map((r) => r.id), parents.map((r) => r.id));
      expect(rows.map((r) => r.many(parentTable.children).length), [
        2,
        0,
        2,
        0,
      ]);
      expect(rows.map((r) => r.many(parentTable.notes).length), [2, 0, 1, 3]);
      expect(rows.first.many(parentTable.children).map((c) => c.rank), [3, 2]);
    },
  );

  test(
    'nullable paths retain Dart inequality; related filters can lock only parents',
    () async {
      expect(
        (await db().relationParents.find(
          where: (t) => t.optionalDetail.label.notEquals('a'),
          orderBy: (t) => [t.id.asc()],
          unbounded: 'fixture',
        )).map((r) => r.id),
        [parents[0].id, parents[2].id, parents[3].id],
      );
      expect(
        await db().relationParents.count(
          where: (t) => t.children.count().gte(1) & t.children.count().lt(3),
        ),
        2,
      );
      await db().transaction((tx) async {
        final locked = await tx.relationParents.find(
          where: (t) => t.detail.label.equals('a'),
          orderBy: (t) => [t.id.asc()],
          lock: DwRowLock.forUpdateSkipLocked,
          limit: 1,
        );
        expect(locked.single.id, parents.first.id);
      });
      await expectLater(
        db().relationParents.updateWhere(
          where: (t) => t.id.equals(parents.first.id),
          set: (t) => [t.detail.label.set('wrong table')],
        ),
        throwsArgumentError,
      );
    },
  );

  test('JSON double carrier retains negative zero and NaN', () async {
    await db().execute('SET extra_float_digits = 0');
    addTearDown(() => db().execute('RESET extra_float_digits'));
    final values = [0.1 + 0.2, -0.0, double.nan, double.negativeInfinity];
    for (final value in values) {
      final detail = await db().relationDetails.insert(
        detailDraft('special').copyWith(doubleValue: value),
      );
      final parent = await db().relationParents.insert(
        NewRelationParentRow(detailId: detail.id, title: 'special'),
      );
      final included = (await db().relationParents.findById(
        parent.id,
        include: (t) => [t.detail],
      ))!.one(parentTable.detail);
      if (value.isNaN) {
        expect(included.doubleValue.isNaN, isTrue);
      } else {
        expect(included.doubleValue, value);
        expect(included.doubleValue.isNegative, value.isNegative);
      }
    }
  });

  test('include bounds, missing selection and locks fail loudly', () async {
    await expectLater(
      db().relationParents.find(include: (t) => [t.detail, t.detail]),
      throwsArgumentError,
    );
    await expectLater(
      db().relationParents.find(
        include: (t) => [
          t.detail.include((d) => [d.ancestor, d.ancestor]),
        ],
      ),
      throwsArgumentError,
    );
    await expectLater(
      db().relationParents.find(include: (t) => [t.children]),
      throwsArgumentError,
    );
    await expectLater(
      db().relationParents.find(include: (t) => [t.children.take(-1)]),
      throwsRangeError,
    );
    await expectLater(
      db().relationParents.find(include: (t) => [t.children.unbounded(' ')]),
      throwsArgumentError,
    );
    await db().transaction((tx) async {
      await expectLater(
        tx.relationParents.find(
          include: (t) => [t.detail],
          lock: DwRowLock.forUpdate,
        ),
        throwsArgumentError,
      );
    });
  });

  test('seeded EXPLAIN uses FK index for include and any, no child seq scan', () async {
    await db().execute('''INSERT INTO relation_parent (detail_id, title, score)
      SELECT 1, 'seed', 0 FROM generate_series(1, 1000);
      INSERT INTO relation_child (parent_id, rank)
      SELECT p.id, n FROM relation_parent p CROSS JOIN generate_series(1, 50) n;
      ANALYZE relation_parent; ANALYZE relation_child;''');
    await db().pinned((pinned) async {
      await pinned.relationParents.find(
        where: (t) => t.id.equals(parents.first.id),
        include: (t) => [
          t.children.take(3, orderBy: (c) => [c.rank.asc()]),
        ],
        limit: 1,
      );
      final includes = await pinned.query(
        "SELECT name FROM pg_prepared_statements WHERE statement LIKE 'SELECT %dw_include_0%' AND statement LIKE '%relation_child%' AND statement NOT LIKE '%pg_prepared_statements%' AND statement NOT LIKE '%dw_include_1%' AND statement LIKE '%LIMIT \$3' AND statement LIKE '%\"rank\" AS \"dw_order_0\"%'",
      );
      final includeName = includes.single
          .get<String>('name')
          .replaceAll('"', '""');
      final includePlan = await pinned.query(
        'EXPLAIN (ANALYZE, BUFFERS) EXECUTE "$includeName"(3, ${parents.first.id}, 1)',
      );
      final includeText = includePlan.map((r) => r.values.first).join('\n');
      expect(includeText, contains('relation_child_parent_id_rank_idx'));
      expect(includeText, isNot(contains('Seq Scan on relation_child')));
      await pinned.relationParents.find(
        where: (t) =>
            t.id.equals(parents.first.id) &
            t.children.any((c) => c.rank.gte(49)),
        limit: 1,
      );
      final queries = await pinned.query(
        "SELECT name FROM pg_prepared_statements WHERE statement LIKE 'SELECT %EXISTS%' AND statement LIKE '%relation_child%' AND statement NOT LIKE '%pg_prepared_statements%' AND statement LIKE '%\"relation_parent\".\"id\" = \$1%'",
      );
      final name = queries.single.get<String>('name').replaceAll('"', '""');
      final plan = await pinned.query(
        'EXPLAIN (ANALYZE, BUFFERS) EXECUTE "$name"(${parents.first.id}, 49, 1)',
      );
      final text = plan.map((r) => r.values.first).join('\n');
      expect(text, contains('relation_child_parent_id_rank_idx'));
      expect(text, isNot(contains('Seq Scan on relation_child')));
    });
  });
}

// Exercise a legal SQL column name without changing the shared fixture schema.
final class _ProjectionTable extends DwTableDef<RelationParentRow> {
  const _ProjectionTable() : super('relation_parent');
  @override
  List<DwTableColumn<Object?>> get tableColumns => [
    ...RelationParentRow.tableDef.tableColumns,
    const DwTableColumn<int>('dw_key', DwColumnType.bigint),
  ];
  @override
  RelationParentRow fromRow(DwResultRow row) =>
      RelationParentRow.tableDef.fromRow(row);
  @override
  Map<String, Object?> toRow(RelationParentRow row) =>
      RelationParentRow.tableDef.toRow(row);
  @override
  Map<String, Object?> toDraftRow(DwRowDraft<RelationParentRow> draft) =>
      RelationParentRow.tableDef.toDraftRow(draft as NewRelationParentRow);
}
