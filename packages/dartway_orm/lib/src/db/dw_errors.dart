import 'package:postgres/postgres.dart' as pg;

/// A failure reported by the database or by the connection to it.
///
/// Every statement the ORM sends maps driver errors into this hierarchy, so a
/// caller never has to know `package:postgres` to tell a constraint violation
/// from a lost connection.
class DwDatabaseException implements Exception {
  DwDatabaseException(this.code, this.message, {this.detail, this.cause});

  /// The SQLSTATE, or `null` when the failure never reached the server
  /// (connection refused, connection closed, timeout on the client side).
  final String? code;
  final String message;
  final String? detail;

  /// The driver exception this was mapped from.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer(runtimeType)
      ..write(code == null ? '' : '[$code]')
      ..write(': ')
      ..write(message);
    if (detail != null) buffer.write(' ($detail)');
    return buffer.toString();
  }
}

/// SQLSTATE 23505.
final class DwUniqueViolation extends DwDatabaseException {
  DwUniqueViolation(
    this.constraint,
    String message, {
    super.detail,
    super.cause,
  }) : super('23505', message);

  final String? constraint;
}

/// SQLSTATE 23503.
final class DwForeignKeyViolation extends DwDatabaseException {
  DwForeignKeyViolation(
    this.constraint,
    String message, {
    super.detail,
    super.cause,
  }) : super('23503', message);

  final String? constraint;
}

/// SQLSTATE 40001: the transaction lost a serialization conflict and may be
/// retried as a whole.
final class DwSerializationFailure extends DwDatabaseException {
  DwSerializationFailure(String message, {super.detail, super.cause})
    : super('40001', message);
}

/// `update` addressed a row that does not exist.
final class DwRowNotFound extends DwDatabaseException {
  DwRowNotFound(this.table, this.id)
    : super(null, 'no row in "$table" with id $id');

  final String table;
  final int id;
}

/// A value read from the database does not fit the Dart type expecting it —
/// the schema and the row class have drifted apart.
final class DwDecodeException extends DwDatabaseException {
  DwDecodeException(String message) : super(null, message);
}

/// Maps a driver error to the DartWay hierarchy. Anything that is not a
/// driver error is returned untouched: it is a bug in the caller, not a
/// database condition, and must keep its own type.
Object dwMapError(Object error) {
  if (error is DwDatabaseException) return error;
  if (error is pg.ServerException) {
    final message = error.message;
    final detail = error.detail;
    return switch (error.code) {
      '23505' => DwUniqueViolation(
        error.constraintName,
        message,
        detail: detail,
        cause: error,
      ),
      '23503' => DwForeignKeyViolation(
        error.constraintName,
        message,
        detail: detail,
        cause: error,
      ),
      '40001' => DwSerializationFailure(message, detail: detail, cause: error),
      _ => DwDatabaseException(
        error.code,
        message,
        detail: detail,
        cause: error,
      ),
    };
  }
  if (error is pg.PgException) {
    return DwDatabaseException(null, error.message, cause: error);
  }
  return error;
}
