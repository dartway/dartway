import 'package:drift/drift.dart';

// Drift resolves composite foreign-key table names through imports.
// ignore: unused_import
import 'dw_offline_packages.dart';

@DataClassName('DwOfflineJobRow')
class DwOfflineJobs extends Table {
  @override
  String get tableName => 'dw_offline_jobs';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get jobId => text().named('job_id')();

  TextColumn get packageId => text().named('package_id').nullable()();

  TextColumn get jobType => text().named('job_type')();

  TextColumn get jobState => text().named('job_state')();

  TextColumn get manifestRevision =>
      text().named('manifest_revision').nullable()();

  TextColumn get manifestDigest => text().named('manifest_digest').nullable()();

  IntColumn get priority => integer()
      .named('priority')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (priority >= 0)')();

  IntColumn get packageTotalBytes => integer()
      .named('package_total_bytes')
      .customConstraint(
        'CHECK (package_total_bytes IS NULL OR package_total_bytes >= 0)',
      )
      .nullable()();

  TextColumn get consentedManifestDigest =>
      text().named('consented_manifest_digest').nullable()();

  IntColumn get nextEligibleAtEpochMs =>
      integer().named('next_eligible_at_epoch_ms').nullable()();

  TextColumn get pauseReason => text().named('pause_reason').nullable()();

  IntColumn get attemptCount => integer()
      .named('attempt_count')
      .customConstraint('NOT NULL CHECK (attempt_count >= 0)')();

  TextColumn get payloadJson => text().named('payload_json')();

  TextColumn get lastErrorJson => text().named('last_error_json').nullable()();

  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, jobId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (user_scope_id, package_id) '
        'REFERENCES dw_offline_packages (user_scope_id, package_id) '
        'ON DELETE CASCADE',
  ];
}
