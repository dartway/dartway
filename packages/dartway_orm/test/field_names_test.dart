import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/field_names/catalog_entry.dart';
import 'support/apply_changes.dart';
import 'support/test_database.dart';

/// D-040: a table definition's own members are `tableName`, `tableColumns`
/// and `tableSchema`, and a row class declares `tableDef`, so row fields may
/// be called `name`, `columns`, `schema`, `table`, `row`, `where` or `order`
/// — SQL keywords among them, which every statement must quote.
void main() {
  final database = useTestDatabase(withFixtureSchema: false);
  DwDatabaseHandle db() => database().db;
  DwTableRepository<CatalogEntryRow, CatalogEntryTable> entries() =>
      db().repository(CatalogEntryRow.tableDef);

  const table = CatalogEntryRow.tableDef;
  final schema = DwDatabaseSchema([table]);

  test('the table definition keeps its own members apart', () {
    expect(table.tableName, 'catalog_entry');
    expect(table.tableColumns.map((column) => column.name), [
      'id',
      'name',
      'schema',
      'columns',
      'table',
      'row',
      'where',
      'order',
    ]);
    expect(table.tableSchema.name, 'catalog_entry');
    expect(table.tableSchema.columns, hasLength(8));
    expect(table.name.name, 'name');
    expect(table.schema.name, 'schema');
    expect(table.columns.name, 'columns');
    expect(table.table.name, 'table');
    expect(table.row.name, 'row');
    expect(table.where.name, 'where');
    expect(table.order.name, 'order');
  });

  test('migrates: created from the diff, introspected back equal', () async {
    final changes = DwSchemaDiff.compare(
      from: DwDatabaseSchema.fromTables(const []),
      to: schema,
    );
    await applyChanges(DwMigrationContext(db()), changes);
    final introspection = await DwSchemaIntrospector.read(db());
    expect(introspection.schema, schema);
    expect(introspection.unmodelled, isEmpty);
    expect(
      DwSchemaDiff.compare(from: introspection.schema, to: schema),
      isEmpty,
    );
  });

  group('round-trips', () {
    setUp(() async {
      if ((await DwSchemaIntrospector.read(
            db(),
          )).schema.table('catalog_entry') ==
          null) {
        await DwMigrationContext(db()).createTable(table.tableSchema);
      }
      await db().execute('TRUNCATE catalog_entry RESTART IDENTITY');
    });

    test(
      'insert, find by every framework-looking column, update, delete',
      () async {
        final stored = await entries().insert(
          const CatalogEntryRow(
            name: 'Chair',
            schema: 'furniture',
            columns: 3,
            table: 7,
            row: 'B',
            where: 'hall',
            order: 2,
          ),
        );
        expect(stored.id, 1);
        expect(
          stored,
          const CatalogEntryRow(
            id: 1,
            name: 'Chair',
            schema: 'furniture',
            columns: 3,
            table: 7,
            row: 'B',
            where: 'hall',
            order: 2,
          ),
        );
        await entries().insertAll([
          const CatalogEntryRow(name: 'Desk', columns: 1, row: 'A', where: 'x'),
          const CatalogEntryRow(
            name: 'Lamp',
            columns: 1,
            row: 'A',
            where: 'y',
            order: 1,
          ),
        ]);

        expect(
          (await entries().findFirst(where: (t) => t.name.equals('Chair')))!.id,
          1,
        );
        expect(await entries().count(where: (t) => t.schema.isNull()), 2);
        expect(await entries().count(where: (t) => t.columns.gt(2)), 1);
        expect(await entries().exists(where: (t) => t.table.equals(7)), isTrue);
        expect(await entries().count(where: (t) => t.row.equals('A')), 2);
        expect(
          (await entries().find(
            where: (t) => t.where.inList(['x', 'y']),
            orderBy: (t) => [t.order.desc()],
          )).map((entry) => entry.name),
          ['Lamp', 'Desk'],
        );

        final updated = await entries().update(
          stored.copyWith(
            name: 'Armchair',
            schema: const DwFieldPatch.clear(),
            row: 'C',
          ),
        );
        expect(updated.name, 'Armchair');
        expect(updated.schema, isNull);
        expect(updated.row, 'C');
        expect(await entries().findById(1), updated);
        expect(
          await entries().updateWhere(
            where: (t) => t.row.equals('A'),
            set: (t) => [t.order.set(9), t.table.set(1)],
          ),
          2,
        );
        expect(
          await entries().count(
            where: (t) => t.order.equals(9) & t.table.equals(1),
          ),
          2,
        );
        expect(
          await entries().deleteWhere(where: (t) => t.where.equals('x')),
          1,
        );
        expect(
          await entries().tryInsert(
            const CatalogEntryRow(
              id: 1,
              name: 'Dup',
              columns: 0,
              row: '',
              where: '',
            ),
            onConflict: DwOnConflict.doNothing((t) => [t.id]),
          ),
          isNull,
        );
      },
    );
  });
}
