import 'package:dartway_core/dartway_core.dart';

/// The server failed a call; [incidentId] is what the operator finds it by.
///
/// The exception form of [DwFailed], for code that meets results as
/// exceptions — an `AsyncValue` error, a guarded UI action.
final class DwFailedException implements Exception {
  const DwFailedException(this.incidentId, {this.call});

  final String incidentId;

  /// The wire name of the request or command that failed, when known.
  final String? call;

  @override
  bool operator ==(Object other) =>
      other is DwFailedException &&
      other.incidentId == incidentId &&
      other.call == call;

  @override
  int get hashCode => Object.hash(incidentId, call);

  @override
  String toString() =>
      'DwFailedException(${call == null ? '' : '$call, '}incident $incidentId)';
}

/// A call needed a signed-in user and the connection had none. The exception
/// form of [DwNotAuthenticated]; the client has already dropped the session.
final class DwNotAuthenticatedException implements Exception {
  const DwNotAuthenticatedException({this.call});

  final String? call;

  @override
  bool operator ==(Object other) =>
      other is DwNotAuthenticatedException && other.call == call;

  @override
  int get hashCode => call.hashCode;

  @override
  String toString() =>
      'DwNotAuthenticatedException(${call ?? 'no signed-in user'})';
}

/// A one-shot call got no answer within `DwClientOptions.callTimeout`.
///
/// For a command the outcome is **unknown**: it may have run. The client has
/// stopped waiting and forgotten the idempotency key, so repeating the intent
/// is a new command — which is why the timeout is generous by default.
final class DwTimeoutException implements Exception {
  const DwTimeoutException(this.call, this.timeout);

  final String call;
  final Duration timeout;

  @override
  String toString() => 'DwTimeoutException($call got no answer in $timeout)';
}

/// The client was stopped before the call was answered.
final class DwClientStoppedException implements Exception {
  const DwClientStoppedException();

  @override
  String toString() => 'DwClientStoppedException()';
}

/// The server said something this client cannot read: an unknown message kind,
/// a DTO the protocol does not register, a result that does not decode. Client
/// and server disagree about the protocol — a deployment problem, never a
/// user's.
final class DwProtocolException implements Exception {
  const DwProtocolException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DwProtocolException: $message${cause == null ? '' : ' ($cause)'}';
}

/// The server speaks another version of the wire protocol and closed the
/// connection with `DwCloseCode.unsupportedVersion`.
///
/// Terminal: the client stops reconnecting, its status becomes
/// `DwConnectionStatus.incompatible`, and every call — waiting or new — ends
/// with this exception. Only another build of the app can talk to this
/// server; an app shows "please update".
final class DwWireVersionException implements Exception {
  const DwWireVersionException({
    required this.clientVersion,
    required this.serverVersion,
  });

  /// `dwWireVersion` of this build.
  final int clientVersion;

  /// The version the server named in its close reason; `null` when the reason
  /// did not name one.
  final int? serverVersion;

  @override
  bool operator ==(Object other) =>
      other is DwWireVersionException &&
      other.clientVersion == clientVersion &&
      other.serverVersion == serverVersion;

  @override
  int get hashCode => Object.hash(clientVersion, serverVersion);

  @override
  String toString() =>
      'DwWireVersionException(client speaks v$clientVersion, server '
      '${serverVersion == null ? 'another version' : 'v$serverVersion'})';
}

/// The server closed the connection because of what this client sent — a
/// frame it could not parse, a binary frame, a message over its size limit
/// (`DwCloseCode.protocolError`, `unsupportedData`, `messageTooBig`). A client
/// bug: the client reconnects with growing backoff, and each such close is
/// reported, since re-sending what caused it will close it again.
final class DwConnectionRejectedException implements Exception {
  const DwConnectionRejectedException(this.closeCode, this.closeReason);

  final int closeCode;
  final String? closeReason;

  @override
  String toString() =>
      'DwConnectionRejectedException($closeCode ${closeReason ?? ''})';
}

/// The server refused a channel subscription because it does not declare the
/// channel kind (`dw.unknownChannel`): a request names a channel the server was
/// never taught. Reported to the client's `onError`; the request works, it just
/// never becomes live.
final class DwChannelRefusedException implements Exception {
  const DwChannelRefusedException(this.channel, this.refusal);

  final String channel;
  final DwRefusal? refusal;

  @override
  String toString() => 'DwChannelRefusedException($channel: $refusal)';
}

/// Signing out reached the server and did not revoke the key: the session is
/// gone on this device, but the token may still be valid until it expires.
final class DwSignOutException implements Exception {
  const DwSignOutException(this.result);

  final DwResult<void> result;

  @override
  String toString() => 'DwSignOutException($result)';
}

/// Results met as exceptions.
extension DwResultValue<R> on DwResult<R> {
  /// The value of a successful result; otherwise the typed exception of the
  /// outcome: [DwRefusalException], [DwNotAuthenticatedException] or
  /// [DwFailedException].
  R get valueOrThrow => switch (this) {
    DwOk(:final value) => value,
    DwRefused(:final refusal) => throw DwRefusalException(refusal),
    DwNotAuthenticated() => throw const DwNotAuthenticatedException(),
    DwFailed(:final incidentId) => throw DwFailedException(incidentId),
  };
}
