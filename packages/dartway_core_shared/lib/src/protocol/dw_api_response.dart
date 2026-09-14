import '../wire/dw_server_call.dart';
import '../result/dw_call_refusal.dart';
import '../result/dw_call_result.dart';
import 'dw_http_contract.dart';
import 'dw_wire_protocol.dart';
import 'dw_read.dart';
import 'dw_update_transport.dart';

/// Why a call failed, as far as the client may know: which of the three
/// failing HTTP statuses it gets. No detail beyond this crosses the wire.
enum DwFailureKind {
  /// The server failed while handling a well-formed call: `500`, and an
  /// alert.
  internal,

  /// The call is not one the protocol allows — a body that does not decode,
  /// a wrong method, a missing or forbidden header, a page parameter the
  /// request kind does not take: `400`. A client bug; no alert.
  malformedCall,

  /// The path names no registered DTO, or one that is not a request or a
  /// command: `404`. A client built against another protocol; no alert.
  unknownCall,
}

/// The body of every answer to `POST /dw/<name>`:
///
/// ```json
/// {"status":"ok","result":<encoded by the call's class>,"updates":{"bookings:7":{"SessionBooking":[…]}}}
/// {"status":"refused","refusal":{"code":"noSpotsLeft"}}
/// {"status":"unauthenticated"}
/// {"status":"failed","incidentId":"…"}
/// {"status":"incompatible","refusal":{"code":"dw.updateRequired"}}
/// ```
///
/// `result` is never tagged (its type is the call's) and is omitted when
/// `null`; `updates` ([DwUpdateTransport]) groups what the call published by
/// channel, then by type, and is omitted when empty. The HTTP status is a
/// function of the body ([dwHttpStatusFor]) declared here, so the server
/// writes and the client checks the same mapping.
sealed class DwApiResponse {
  const DwApiResponse();

  /// Success: the call's [result], already encoded by its class, and the
  /// [updates] the call published that the caller should apply.
  const factory DwApiResponse.ok(
    Object? result, {
    DwUpdateTransport updates,
    bool replayed,
  }) = DwApiOk;

  /// Refused by a rule or validation. Throws [ArgumentError] for an
  /// incompatibility code, which answers [DwApiResponse.incompatible].
  factory DwApiResponse.refused(DwCallRefusal refusal) = DwApiRefused;

  /// The call needs a signed-in caller and has none (or its key is revoked).
  const factory DwApiResponse.unauthenticated() = DwApiUnauthenticated;

  /// The call failed; [incidentId] is what the operator finds it by.
  const factory DwApiResponse.failed(
    String incidentId, {
    DwFailureKind failure,
  }) = DwApiFailed;

  /// This build cannot talk to this server. Throws [ArgumentError] unless the
  /// refusal is one of [DwCoreRefusal.incompatibilities].
  factory DwApiResponse.incompatible(DwCallRefusal refusal) = DwApiIncompatible;

  /// Reads a response body. Throws [FormatException] for a body that is not
  /// one of the five shapes, or whose updates do not decode with [protocol].
  factory DwApiResponse.fromJson(Object? json, DwWireProtocol protocol) {
    const what = 'An API response';
    final map = dwReadMap(json, what);
    final status = dwReadString(map['status'], 'The response status');
    DwCallRefusal refusal() => DwCallRefusal.fromJson(map['refusal']);
    switch (status) {
      case _ok:
        dwRejectUnknownKeys(map, const {
          'status',
          'result',
          'updates',
          'replayed',
        }, what);
        final updates = map['updates'];
        final replayed = map['replayed'];
        if (replayed != null && replayed != true) {
          throw FormatException('$what has a malformed "replayed": $replayed');
        }
        return DwApiOk(
          map['result'],
          updates: updates == null
              ? DwUpdateTransport.empty
              : DwUpdateTransport.fromJson(updates, protocol),
          replayed: replayed == true,
        );
      case _refused:
        dwRejectUnknownKeys(map, const {'status', 'refusal'}, what);
        return _inShape(() => DwApiRefused(refusal()));
      case _unauthenticated:
        dwRejectUnknownKeys(map, const {'status'}, what);
        return const DwApiUnauthenticated();
      case _failed:
        dwRejectUnknownKeys(map, const {
          'status',
          'incidentId',
          'failure',
        }, what);
        final failure = map['failure'];
        return DwApiFailed(
          dwReadString(map['incidentId'], 'The incident id'),
          failure: failure == null
              ? DwFailureKind.internal
              : _failureNamed(dwReadString(failure, 'The failure')),
        );
      case _incompatible:
        dwRejectUnknownKeys(map, const {'status', 'refusal'}, what);
        return _inShape(() => DwApiIncompatible(refusal()));
      default:
        throw FormatException('$what has an unknown status "$status"');
    }
  }

  /// Reads an answer as the client receives it: the body, and the HTTP
  /// [status] it came with, which must be the one [dwHttpStatusFor] gives —
  /// a disagreement means the body did not come from a DartWay server of
  /// this protocol (a proxy's error page, a misrouted request), and is
  /// thrown as [FormatException] rather than trusted.
  factory DwApiResponse.fromHttp(
    int status,
    Object? json,
    DwWireProtocol protocol,
  ) {
    final response = DwApiResponse.fromJson(json, protocol);
    final expected = dwHttpStatusFor(response);
    if (expected != status) {
      throw FormatException(
        'HTTP $status does not match the response ${response.runtimeType}, '
        'which a DartWay server answers with $expected',
      );
    }
    return response;
  }

  static const _ok = 'ok';
  static const _refused = 'refused';
  static const _unauthenticated = 'unauthenticated';
  static const _failed = 'failed';
  static const _incompatible = 'incompatible';

  static DwApiResponse _inShape(DwApiResponse Function() build) {
    try {
      return build();
    } on ArgumentError catch (error) {
      throw FormatException('${error.message}');
    }
  }

  static DwFailureKind _failureNamed(String name) {
    for (final failure in DwFailureKind.values) {
      if (failure.name == name) return failure;
    }
    throw FormatException('Unknown failure "$name"');
  }

  Map<String, Object?> toJson();

  /// The HTTP status this response is sent with.
  int get httpStatus => dwHttpStatusFor(this);

  /// The response as the caller's typed result, its value decoded by [call].
  ///
  /// An incompatibility becomes a [DwCallRefused] carrying its code: the result
  /// of a call has four outcomes, and "update the app" is one the app renders
  /// from the refusal code. Updates are not part of the result; the client
  /// applies [DwApiOk.updates] before handing the result on. Throws
  /// [FormatException] when the result does not decode as [call]'s.
  DwCallResult<R> toResult<R>(DwServerCall<R> call, DwWireProtocol protocol) =>
      switch (this) {
        DwApiOk(:final result) => DwCallOk(call.decodeResult(result, protocol)),
        DwApiRefused(:final refusal) ||
        DwApiIncompatible(:final refusal) => DwCallRefused(refusal),
        DwApiUnauthenticated() => const DwNotAuthenticated(),
        DwApiFailed(:final incidentId) => DwCallFailed(incidentId),
      };
}

/// See [DwApiResponse.ok].
final class DwApiOk extends DwApiResponse {
  const DwApiOk(
    this.result, {
    this.updates = DwUpdateTransport.empty,
    this.replayed = false,
  });

  /// The call's result, encoded by its class; `null` for an absent maybe or
  /// a `void` command.
  final Object? result;

  final DwUpdateTransport updates;

  /// The stored outcome of an earlier execution of the same command, answered
  /// again for a repeated idempotency key. It carries no updates — the first
  /// execution's updates went out when it ran, possibly while the caller's
  /// answer was lost — so a client receiving a replay re-reads its live state
  /// instead of trusting it (rare: it takes a lost response).
  final bool replayed;

  @override
  Map<String, Object?> toJson() => {
    'status': DwApiResponse._ok,
    if (result != null) 'result': result,
    if (updates.isNotEmpty) 'updates': updates.toJson(),
    if (replayed) 'replayed': true,
  };

  @override
  String toString() => 'DwApiOk($result, $updates)';
}

/// See [DwApiResponse.refused].
final class DwApiRefused extends DwApiResponse {
  DwApiRefused(this.refusal) {
    if (refusal.isIncompatibility) {
      throw ArgumentError.value(
        refusal.code,
        'refusal',
        'an incompatibility is answered as incompatible, not refused',
      );
    }
  }

  final DwCallRefusal refusal;

  @override
  Map<String, Object?> toJson() => {
    'status': DwApiResponse._refused,
    'refusal': refusal.toJson(),
  };

  @override
  String toString() => 'DwApiRefused($refusal)';
}

/// See [DwApiResponse.unauthenticated].
final class DwApiUnauthenticated extends DwApiResponse {
  const DwApiUnauthenticated();

  @override
  Map<String, Object?> toJson() => const {
    'status': DwApiResponse._unauthenticated,
  };

  @override
  String toString() => 'DwApiUnauthenticated()';
}

/// See [DwApiResponse.failed].
final class DwApiFailed extends DwApiResponse {
  const DwApiFailed(this.incidentId, {this.failure = DwFailureKind.internal});

  final String incidentId;
  final DwFailureKind failure;

  @override
  Map<String, Object?> toJson() => {
    'status': DwApiResponse._failed,
    'incidentId': incidentId,
    if (failure != DwFailureKind.internal) 'failure': failure.name,
  };

  @override
  String toString() => 'DwApiFailed($incidentId, ${failure.name})';
}

/// See [DwApiResponse.incompatible].
final class DwApiIncompatible extends DwApiResponse {
  DwApiIncompatible(this.refusal) {
    if (!refusal.isIncompatibility) {
      throw ArgumentError.value(
        refusal.code,
        'refusal',
        'only ${DwCoreRefusal.incompatibilities.map((c) => c.code).join(' '
        'and ')} are incompatibilities',
      );
    }
  }

  final DwCallRefusal refusal;

  @override
  Map<String, Object?> toJson() => {
    'status': DwApiResponse._incompatible,
    'refusal': refusal.toJson(),
  };

  @override
  String toString() => 'DwApiIncompatible($refusal)';
}

/// The HTTP status of [response] — one mapping for the server that sends it
/// and the client that checks it.
///
/// | Response | Status |
/// |---|---|
/// | ok | 200 |
/// | refused `dw.forbidden` / `dw.notFound` / `dw.conflict` | 403 / 404 / 409 |
/// | refused `dw.tooManyRequests` | 429, with `Retry-After` |
/// | refused, any other code | 422 |
/// | unauthenticated | 401 |
/// | failed: internal / malformed call / unknown call | 500 / 400 / 404 |
/// | incompatible | 426 |
///
/// Only a `5xx` alerts the operator: refusals are answers, and the `4xx`
/// failures are a client's mistake.
int dwHttpStatusFor(DwApiResponse response) => switch (response) {
  DwApiOk() => 200,
  DwApiRefused(:final refusal) => _refusedStatus(refusal),
  DwApiUnauthenticated() => 401,
  DwApiFailed(:final failure) => switch (failure) {
    DwFailureKind.internal => 500,
    DwFailureKind.malformedCall => 400,
    DwFailureKind.unknownCall => 404,
  },
  DwApiIncompatible() => 426,
};

/// The headers [response] needs besides the content type: `Retry-After` on a
/// `dw.tooManyRequests` refusal, nothing otherwise.
Map<String, String> dwHttpHeadersFor(DwApiResponse response) =>
    switch (response) {
      DwApiRefused(refusal: DwCallRefusal(:final retryAfter?)) => {
        DwHttpContract.retryAfterHeader: '${retryAfter.inSeconds}',
      },
      _ => const {},
    };

int _refusedStatus(DwCallRefusal refusal) {
  if (refusal.isCode(DwCoreRefusal.forbidden)) return 403;
  if (refusal.isCode(DwCoreRefusal.notFound)) return 404;
  if (refusal.isCode(DwCoreRefusal.conflict)) return 409;
  if (refusal.isCode(DwCoreRefusal.tooManyRequests)) return 429;
  return 422;
}
