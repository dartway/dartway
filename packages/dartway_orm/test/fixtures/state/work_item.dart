import 'package:dartway_orm/dartway_orm.dart';

part 'work_item.dw.dart';

enum WorkStatus { open, running, completed, cancelled }

const workTransitions = DwStateTransitions<WorkStatus>(
  initial: {WorkStatus.open},
  moves: {
    WorkStatus.open: {WorkStatus.running, WorkStatus.cancelled},
    WorkStatus.running: {WorkStatus.completed, WorkStatus.cancelled},
  },
);

@DwSqlTable('work_item')
final class WorkItemRow extends DwTableRow with _$WorkItemRow {
  const WorkItemRow({
    required this.id,
    required this.status,
    required this.title,
  });

  @override
  final int id;
  @DwStateColumn(workTransitions)
  final WorkStatus status;
  @DwUniqueColumn()
  final String title;

  static const tableDef = WorkItemTable();
}
