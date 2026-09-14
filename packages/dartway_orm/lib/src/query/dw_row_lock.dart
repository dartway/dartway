import 'package:meta/meta.dart';

import '../entity/dw_table_def.dart';
import 'dw_table_column.dart';

/// A row lock taken by a read. Allowed only inside a transaction: outside one
/// the lock would be released as soon as the statement ends, which reads like
/// protection and is none.
enum DwRowLock {
  /// `FOR UPDATE`: waits for rows another transaction holds.
  forUpdate(' FOR UPDATE'),

  /// `FOR UPDATE SKIP LOCKED`: returns only rows nobody holds — how
  /// concurrent workers claim distinct jobs from one queue.
  forUpdateSkipLocked(' FOR UPDATE SKIP LOCKED');

  const DwRowLock(this.sql);

  @internal
  final String sql;
}

/// The isolation level of a transaction.
enum DwIsolationLevel {
  readCommitted('READ COMMITTED'),
  repeatableRead('REPEATABLE READ'),

  /// Conflicts surface as `DwSerializationFailure`; the caller retries the
  /// whole transaction.
  serializable('SERIALIZABLE');

  const DwIsolationLevel(this.sql);

  @internal
  final String sql;
}

/// What `tryInsert` does when the row conflicts with a unique constraint.
sealed class DwOnConflict<T extends DwTableDef> {
  const DwOnConflict();

  /// Skip the row; `tryInsert` returns `null`. The [target] columns name the
  /// unique constraint or index the conflict is expected on; an empty list
  /// accepts a conflict on any of them.
  const factory DwOnConflict.doNothing(
    List<DwTableColumn<Object?>> Function(T table) target,
  ) = _DwDoNothing<T>;

  @internal
  String sql(T table);
}

final class _DwDoNothing<T extends DwTableDef> extends DwOnConflict<T> {
  const _DwDoNothing(this.target);

  final List<DwTableColumn<Object?>> Function(T table) target;

  @override
  String sql(T table) {
    final columns = target(table);
    return columns.isEmpty
        ? ' ON CONFLICT DO NOTHING'
        : ' ON CONFLICT (${columns.map((column) => column.sql).join(', ')}) DO NOTHING';
  }
}
