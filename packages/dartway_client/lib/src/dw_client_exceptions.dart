import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The server failed a call; [incidentId] is what the operator finds it by.
///
/// The exception form of [DwCallFailed], for code that meets results as
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

/// A call needed a signed-in user and had none. The exception form of
/// [DwNotAuthenticated]; the client has already dropped the session.
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

/// A call got no answer within `DwClientOptions.callTimeout`: the server was
/// unreachable (every attempt failed on the network) or did not answer in
/// time.
///
/// For a command the outcome is **unknown**: it may have run. The client has
/// stopped retrying and forgotten the idempotency key, so repeating the
/// intent is a new command — which is why the timeout is generous by default.
final class DwTimeoutException implements Exception {
  const DwTimeoutException(this.call, this.timeout, {this.lastError});

  /// The wire name of the call.
  final String call;

  final Duration timeout;

  /// What the last attempt failed with — a socket error, a proxy's `503` —
  /// when an attempt failed rather than hung.
  final Object? lastError;

  @override
  bool operator ==(Object other) =>
      other is DwTimeoutException &&
      other.call == call &&
      other.timeout == timeout;

  @override
  int get hashCode => Object.hash(call, timeout);

  @override
  String toString() =>
      'DwTimeoutException($call got no answer in $timeout'
      '${lastError == null ? '' : '; last error: $lastError'})';
}

/// The client was stopped before the call was answered.
final class DwClientStoppedException implements Exception {
  const DwClientStoppedException();

  @override
  bool operator ==(Object other) => other is DwClientStoppedException;

  @override
  int get hashCode => (DwClientStoppedException).hashCode;

  @override
  String toString() => 'DwClientStoppedException()';
}

/// The server said something this client cannot read: a body that is not an
/// API response, a status that does not match its body, a result that does
/// not decode, a live message of an unknown kind. Client and server disagree
/// about the protocol — a deployment problem, never a user's.
final class DwProtocolException implements Exception {
  const DwProtocolException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DwProtocolException: $message${cause == null ? '' : ' ($cause)'}';
}

/// The server closed the live socket because of what this client sent — a
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
/// channel kind (`dw.unknownChannel`): a request names a channel the server
/// was never taught. Reported to the client's `onError`; the request works,
/// it just never becomes live.
final class DwChannelRefusedException implements Exception {
  const DwChannelRefusedException(this.channel, this.refusal);

  final String channel;
  final DwCallRefusal refusal;

  @override
  String toString() => 'DwChannelRefusedException($channel: $refusal)';
}

/// A channel subscription check failed on the server — an incident, reported
/// because the data it leaves behind silently stops being live.
final class DwChannelFailedException implements Exception {
  const DwChannelFailedException(this.channel, this.incidentId);

  final String channel;
  final String incidentId;

  @override
  String toString() => 'DwChannelFailedException($channel, $incidentId)';
}

/// Signing out reached the server and did not revoke the key: the session is
/// gone on this device, but the token may still be valid.
final class DwSignOutException implements Exception {
  const DwSignOutException(this.outcome);

  /// A [DwCallResult] other than success, or the exception the call ended
  /// with ([DwTimeoutException], [DwProtocolException]).
  final Object outcome;

  @override
  String toString() => 'DwSignOutException($outcome)';
}

/// Results met as exceptions.
extension DwCallResultValue<R> on DwCallResult<R> {
  /// The value of a successful result; otherwise the typed exception of the
  /// outcome: [DwRefusalException], [DwNotAuthenticatedException] or
  /// [DwFailedException].
  R get valueOrThrow => switch (this) {
    DwCallOk(:final value) => value,
    DwCallRefused(:final refusal) => throw DwRefusalException(refusal),
    DwNotAuthenticated() => throw const DwNotAuthenticatedException(),
    DwCallFailed(:final incidentId) => throw DwFailedException(incidentId),
  };
}

/// Why an upload's bytes did not reach storage.
enum DwUploadFailure {
  /// Every attempt failed on the network, stalled, or met a transient
  /// answer (`408`, `429`, `5xx`) until the ticket expired. Nothing is wrong with the file; the user tries again later.
  unreachable,

  /// Storage refused the upload ([DwUploadException.status]): the ticket
  /// does not match what was sent, the bucket is misconfigured (CORS, keys),
  /// or storage is down in a way retries did not outlast.
  rejected,

  /// The ticket expired before an attempt could finish — a very slow
  /// network, or a device clock far from the server's. A new upload starts
  /// with a new ticket.
  expired,
}

/// The bytes of an upload did not reach storage. The server's part — the
/// ticket, the confirmation — is answered as a `DwCallResult`; this is the
/// part between the client and storage, where no server answers.
final class DwUploadException implements Exception {
  const DwUploadException(
    this.failure, {
    this.status,
    this.storageCode,
    this.lastError,
  });

  final DwUploadFailure failure;

  /// Storage's HTTP status: the refusal of [DwUploadFailure.rejected] and
  /// [DwUploadFailure.expired], the last transient answer of
  /// [DwUploadFailure.unreachable] when there was one.
  final int? status;

  /// S3's error `<Code>` (`AccessDenied`, `SignatureDoesNotMatch`), when the
  /// answer had one.
  final String? storageCode;

  /// What the last failed attempt threw.
  final Object? lastError;

  @override
  String toString() =>
      'DwUploadException(${failure.name}'
      '${status == null ? '' : ', HTTP $status'}'
      '${storageCode == null ? '' : ' $storageCode'}'
      '${lastError == null ? '' : '; last error: $lastError'})';
}
