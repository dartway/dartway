import 'dw_call_refusal.dart';

/// The answer to every request and command. Exhaustive by construction: a
/// caller that switches over it cannot forget the refusal or the failure.
sealed class DwCallResult<R> {
  const DwCallResult();

  /// The value of a successful result, or `null` for any other.
  R? get valueOrNull => switch (this) {
    DwCallOk(:final value) => value,
    _ => null,
  };

  bool get isOk => this is DwCallOk<R>;
}

/// Success.
final class DwCallOk<R> extends DwCallResult<R> {
  const DwCallOk(this.value);

  final R value;

  @override
  String toString() => 'DwCallOk($value)';
}

/// The server refused: an answer for the user, not an incident.
final class DwCallRefused<R> extends DwCallResult<R> {
  const DwCallRefused(this.refusal);

  final DwCallRefusal refusal;

  @override
  String toString() => 'DwCallRefused($refusal)';
}

/// The call needs a signed-in user and the connection has none (or its key was
/// revoked). The client signs out instead of showing an error.
final class DwNotAuthenticated<R> extends DwCallResult<R> {
  const DwNotAuthenticated();

  @override
  String toString() => 'DwNotAuthenticated()';
}

/// The server failed. No detail crosses the wire: [incidentId] is what the
/// operator finds the exception by.
final class DwCallFailed<R> extends DwCallResult<R> {
  const DwCallFailed(this.incidentId);

  final String incidentId;

  @override
  String toString() => 'DwCallFailed($incidentId)';
}
