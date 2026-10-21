import 'package:dartway_cli/src/checker/dw_state_columns.dart';
import 'package:test/test.dart';

const rows = '''
@DwSqlTable('work_item')
final class WorkItemRow extends DwTableRow with _\$WorkItemRow {
  @DwColumnName('life_state')
  @DwStateColumn(workTransitions)
  final WorkStatus status;
  final String title;
}
''';
const schema = 'get workItems => repository(WorkItemRow.tableDef);';

void main() {
  final cases = <String, bool>{
    'void f(WorkItemRow row) { row.copyWith(status: next); }': true,
    'final row = await ctx.db.workItems.findById(id); row!.copyWith(status: next);':
        true,
    'final row = ctx.accessed<WorkItemRow>(); row.copyWith(status: next);':
        true,
    'final repo = ctx.db.workItems; final row = await repo.findFirst(); row.copyWith(status: next);':
        true,
    'ctx.db.workItems.update(WorkItemRow(id: id, status: next));': true,
    'ctx.db.workItems.updateWhere(where: (t) => t.id.equals(id), set: (t) => [t.status.set(next)]);':
        true,
    'ctx.db.workItems.updateWhereReturning(where: (t) => t.id.equals(id), set: (t) => [t.status.set(next)]);':
        true,
    'ctx.db.workItems.upsert(draft, conflictOn: (t) => [t.title]);': true,
    '''db.execute('UPDATE work_item SET life_state = @next');''': true,
    '''db.execute('UPDATE "work_item" SET title = @title, "life_state" = @next');''':
        true,
    '''db.execute('INSERT INTO work_item (life_state) VALUES (@next)');''':
        true,
    'void f(WorkItemRow row) { row.copyWith(title: next); }': false,
    'void f(WorkItemDto row) { row.copyWith(status: next); }': false,
    'ctx.db.workItems.update(row);': false,
    'void f(WorkItemRow row) { ctx.db.workItems.update(row.copyWith(status: row.status, title: next)); }':
        false,
    'final row = await ctx.db.workItems.findById(id); ctx.db.workItems.update(row!.copyWith(status: row.status, title: next));':
        false,
    'void f(WorkItemRow row) { row.copyWith(status: row.status); }': false,
    'void f(WorkItemRow row, WorkItemRow other) { row.copyWith(title: change(other.copyWith(status: row.status))); }':
        true,
    'void f(WorkItemRow row, WorkItemRow other) { ctx.db.workItems.update(row.copyWith(status: other.status)); }':
        true,
    'void f(WorkItemRow row) { ctx.db.workItems.update(row.copyWith(status: transform(row.status))); }':
        true,
    'void f(WorkItemRow row) { ctx.db.workItems.update(WorkItemRow(id: row.id, status: row.status, title: next)); }':
        false,
    'ctx.db.workItems.transition(id, column: (t) => t.status, to: next);':
        false,
    'ctx.db.workItems.insert(NewWorkItemRow(status: initial));': false,
    '// row.copyWith(status: next);': false,
    '''db.execute('UPDATE work_item SET title = @title');''': false,
    '''db.execute('UPDATE other_item SET life_state = @next');''': false,
  };
  for (final entry in cases.entries) {
    test(entry.key, () {
      final found = DwStateColumnsInspector.writesIn({
        'lib/src/work/work_rows.dart': rows,
        'lib/generated/dw_schema.dart': schema,
        'lib/src/work/work_changes.dart': entry.key,
      });
      expect(found.isNotEmpty, entry.value, reason: found.join('\n'));
    });
  }
  test('only a migration backfill may write state through raw SQL', () {
    const write = "m.backfill('UPDATE work_item SET life_state = @next');";
    expect(
      DwStateColumnsInspector.writesIn({
        'lib/rows.dart': rows,
        'lib/src/migrations/m001.dart': write,
      }),
      isEmpty,
    );
    expect(
      DwStateColumnsInspector.writesIn({
        'lib/rows.dart': rows,
        'lib/src/work/work_changes.dart': write,
      }),
      hasLength(1),
    );
  });
}
