import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/state/work_item.dart';
import 'support/test_database.dart';

void main() {
  final database = useTestDatabase(
    withFixtureSchema: false,
    countRoundTrips: true,
    maxConnections: 1,
  );
  const table = WorkItemRow.tableDef;
  late DwTableRepository<WorkItemRow, WorkItemTable> items;
  setUpAll(() async {
    await DwMigrationContext(database().db).createTable(table.tableSchema);
    items = database().db.repository(table);
  });
  setUp(() => items.deleteWhere(where: (t) => t.id.gt(0)));
  const draft = NewWorkItemRow(status: WorkStatus.open, title: 'Ship');
  final refused = throwsA(isA<DwStateWriteException>());

  test(
    'all insert paths refuse noninitial values without partial writes',
    () async {
      final invalid = draft.copyWith(status: WorkStatus.completed);
      await expectLater(items.insert(invalid), refused);
      await expectLater(
        items.tryInsert(
          invalid,
          onConflict: DwOnConflict.doNothing((t) => [t.title]),
        ),
        refused,
      );
      await expectLater(items.insertAll([draft, invalid]), refused);
      expect(await items.count(), 0);
    },
  );

  test(
    'ordinary updates retain state and refuse intentional state changes',
    () async {
      final row = await items.insert(draft);
      expect(
        (await items.update(row.copyWith(title: 'Rename'))).status,
        WorkStatus.open,
      );
      await expectLater(
        () => items.update(row.copyWith(status: WorkStatus.running)),
        refused,
      );
      await expectLater(
        items.updateWhere(
          where: (t) => t.id.equals(row.id),
          set: (t) => [t.status.set(WorkStatus.running)],
        ),
        refused,
      );
      await expectLater(
        items.updateWhereReturning(
          where: (t) => t.id.equals(row.id),
          set: (t) => [t.status.set(WorkStatus.running)],
        ),
        refused,
      );
      // A caller cannot forge a plain column to bypass its declared metadata.
      await expectLater(
        items.updateWhere(
          where: (t) => t.id.equals(row.id),
          set: (_) => [
            const DwTableColumn(
              'status',
              DwEnumType(WorkStatus.values),
            ).set(WorkStatus.running),
          ],
        ),
        refused,
      );
    },
  );

  test(
    'a stale ordinary edit after a worker transition is catchable',
    () async {
      final row = await items.insert(draft);
      final worker = await database().openAnother();
      addTearDown(worker.close);
      await worker.db
          .repository(table)
          .transition(row.id, column: (t) => t.status, to: WorkStatus.running);
      await expectLater(
        items.update(row.copyWith(status: row.status, title: 'Stale')),
        throwsA(isA<DwStaleState>()),
      );
      final stored = (await items.findById(row.id))!;
      expect(stored.title, 'Ship');
      expect(stored.status, WorkStatus.running);
    },
  );

  test('a missing state-table row remains DwRowNotFound', () async {
    final row = await items.insert(draft);
    await items.delete(row.id);
    await expectLater(
      items.update(row.copyWith(title: 'Deleted')),
      throwsA(isA<DwRowNotFound>()),
    );
  });

  test('a stored row copy refuses a changed state before any write', () async {
    final row = await items.insert(draft);
    expect(() => row.copyWith(status: WorkStatus.running), refused);
    expect(row.copyWith(status: row.status).status, WorkStatus.open);
  });

  test('upsert paths cannot reset an existing state', () async {
    final row = await items.insert(draft);
    await items.transition(
      row.id,
      column: (t) => t.status,
      to: WorkStatus.running,
    );
    await expectLater(
      items.upsert(draft, conflictOn: (t) => [t.title]),
      refused,
    );
    await expectLater(
      items.upsertAll([draft], conflictOn: (t) => [t.title]),
      refused,
    );
    expect((await items.findById(row.id))!.status, WorkStatus.running);
  });

  test(
    'the directed table is enforced, including terminal, missing and self moves',
    () async {
      for (final entry in workTransitions.moves.entries) {
        for (final to in entry.value) {
          final row = await items.insert(draft);
          if (entry.key != WorkStatus.open) {
            await items.transition(
              row.id,
              column: (t) => t.status,
              to: entry.key,
            );
          }
          final changed = await items.transition(
            row.id,
            column: (t) => t.status,
            to: to,
          );
          expect(changed!.status, to);
          await items.delete(row.id);
        }
      }
      final row = await items.insert(draft);
      expect(
        await items.transition(
          row.id,
          column: (t) => t.status,
          to: WorkStatus.completed,
        ),
        isNull,
      );
      expect(
        await items.transition(
          row.id,
          column: (t) => t.status,
          to: WorkStatus.open,
        ),
        isNull,
      );
      await items.transition(
        row.id,
        column: (t) => t.status,
        to: WorkStatus.cancelled,
      );
      expect(
        await items.transition(
          row.id,
          column: (t) => t.status,
          to: WorkStatus.running,
        ),
        isNull,
      );
      expect(
        await items.transition(
          -1,
          column: (t) => t.status,
          to: WorkStatus.running,
        ),
        isNull,
      );
      await expectLater(
        items.transition(row.id, column: (t) => t.title, to: 'No'),
        throwsArgumentError,
      );
    },
  );

  test(
    'bulk transition returns exactly the changed ids in one statement',
    () async {
      final rows = await items.insertAll([
        draft,
        draft.copyWith(title: 'Other'),
        draft.copyWith(title: 'Leave'),
      ]);
      await items.transition(
        rows[1].id,
        column: (t) => t.status,
        to: WorkStatus.cancelled,
      );
      // Prepare this statement shape before measuring its execution.
      await items.transitionWhere(
        where: (t) => t.id.inList([-1]),
        column: (t) => t.status,
        to: WorkStatus.running,
      );
      final before = database().database.roundTrips;
      final changed = await items.transitionWhere(
        where: (t) => t.id.inList([rows[0].id, rows[1].id, -1]),
        column: (t) => t.status,
        to: WorkStatus.running,
      );
      expect(database().database.roundTrips - before, 1);
      expect(changed.map((r) => r.id), [rows[0].id]);
      expect((await items.findById(rows[2].id))!.status, WorkStatus.open);
    },
  );

  test(
    'two concurrent transitions recheck the stored state: exactly one wins',
    () async {
      final row = await items.insert(draft);
      final other = await database().openAnother();
      addTearDown(other.close);
      final competing = other.db.repository(table);
      final outcomes = await Future.wait([
        items.transition(
          row.id,
          column: (t) => t.status,
          to: WorkStatus.cancelled,
        ),
        competing.transition(
          row.id,
          column: (t) => t.status,
          to: WorkStatus.cancelled,
        ),
      ]);
      expect(outcomes.whereType<WorkItemRow>(), hasLength(1));
      expect((await items.findById(row.id))!.status, WorkStatus.cancelled);
    },
  );
}
