import 'package:drift/drift.dart';

// Drift resolves composite foreign-key table names through imports.
// ignore: unused_import
import 'dw_offline_assets.dart';
// ignore: unused_import
import 'dw_offline_jobs.dart';

@DataClassName('DwOfflineDownloadTaskRow')
class DwOfflineDownloadTasks extends Table {
  @override
  String get tableName => 'dw_offline_download_tasks';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get jobId => text().named('job_id')();

  TextColumn get assetId => text().named('asset_id')();

  TextColumn get assetRevision => text().named('asset_revision')();

  BoolColumn get isRequired =>
      boolean().named('is_required').withDefault(const Constant(true))();

  TextColumn get taskState => text().named('task_state')();

  TextColumn get nativeTaskId => text().named('native_task_id').nullable()();

  TextColumn get temporaryFilePath =>
      text().named('temporary_file_path').nullable()();

  IntColumn get transferredBytes => integer()
      .named('transferred_bytes')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (transferred_bytes >= 0)')();

  IntColumn get attemptCount => integer()
      .named('attempt_count')
      .customConstraint('NOT NULL CHECK (attempt_count >= 0)')();

  IntColumn get nextEligibleAtEpochMs =>
      integer().named('next_eligible_at_epoch_ms').nullable()();

  TextColumn get lastErrorJson => text().named('last_error_json').nullable()();

  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {
    userScopeId,
    jobId,
    assetId,
    assetRevision,
  };

  @override
  List<String> get customConstraints => [
    'UNIQUE (native_task_id)',
    'FOREIGN KEY (user_scope_id, job_id) '
        'REFERENCES dw_offline_jobs (user_scope_id, job_id) ON DELETE CASCADE',
    'FOREIGN KEY (user_scope_id, asset_id, asset_revision) '
        'REFERENCES dw_offline_assets '
        '(user_scope_id, asset_id, asset_revision) ON DELETE RESTRICT',
  ];
}
