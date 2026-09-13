import 'dw_refusal.dart';

/// The answer to every request and command. Exhaustive by construction: a
/// caller that switches over it cannot forget the refusal or the failure.
sealed class DwResult<R> {
  const DwResult();

  /// The value of a successful result, or `null` for any other.
  R? get valueOrNull => switch (this) {
    DwOk(:final value) => value,
    _ => null,
  };

  bool get isOk => this is DwOk<R>;
}

/// Success.
final class DwOk<R> extends DwResult<R> {
  const DwOk(this.value);

  final R value;

  @override
  String toString() => 'DwOk($value)';
}

/// The server refused: an answer for the user, not an incident.
final class DwRefused<R> extends DwResult<R> {
  const DwRefused(this.refusal);

  final DwRefusal refusal;

  @override
  String toString() => 'DwRefused($refusal)';
}

/// The call needs a signed-in user and the connection has none (or its key was
/// revoked). The client signs out instead of showing an error.
final class DwNotAuthenticated<R> extends DwResult<R> {
  const DwNotAuthenticated();

  @override
  String toString() => 'DwNotAuthenticated()';
}

/// The server failed. No detail crosses the wire: [incidentId] is what the
/// operator finds the exception by.
final class DwFailed<R> extends DwResult<R> {
  const DwFailed(this.incidentId);

  final String incidentId;

  @override
  String toString() => 'DwFailed($incidentId)';
}
