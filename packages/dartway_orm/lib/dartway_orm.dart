/// Typed PostgreSQL access, schema and migrations for DartWay servers.
library;

// Generated row code uses these; re-exported so a row class file needs one
// import.
export 'package:dartway_core_shared/dartway_core_shared.dart'
    show
        DwClearField,
        DwKeepField,
        DwFieldPatch,
        DwFieldPatchApply,
        DwSetField,
        dwListEquals,
        dwMapEquals;

export 'src/db/dw_postgres_database.dart' show DwPostgresDatabase;
export 'src/db/dw_database_config.dart' show DwDatabaseConfig;
export 'src/db/dw_database_handle.dart' show DwDatabaseHandle;
export 'src/db/dw_errors.dart'
    show
        DwDatabaseException,
        DwDecodeException,
        DwRowNotFound,
        DwForeignKeyViolation,
        DwSerializationFailure,
        DwUniqueViolation;
export 'src/db/dw_result_row.dart' show DwResultRow;
export 'src/entity/dw_annotations.dart';
export 'src/entity/dw_table_row.dart';
export 'src/entity/dw_table_def.dart';
export 'src/entity/dw_column_type.dart';
export 'src/migrations/dw_database_migration.dart';
export 'src/migrations/dw_migration_errors.dart';
export 'src/migrations/dw_migration_runner.dart';
export 'src/query/dw_table_column.dart' hide DwSqlWriter, dwQuoteIdentifier;
export 'src/query/dw_row_lock.dart';
export 'src/query/dw_table_repository.dart';
export 'src/schema/dw_database_schema.dart' hide dwCheckIdentifier;
export 'src/migrations/dw_migration_cli.dart';
export 'src/schema/dw_schema_introspector.dart';
export 'src/schema/dw_schema_diff.dart';
