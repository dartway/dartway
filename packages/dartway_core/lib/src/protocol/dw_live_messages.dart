import '../result/dw_refusal.dart';
import 'dw_protocol.dart';
import 'dw_read.dart';
import 'dw_transport.dart';

// The messages of the live WebSocket (`GET /dw/live`). Calls do not travel
// here — they are HTTP — so the socket carries only what HTTP cannot: the
// connection's identity and authentication, channel subscriptions, and the
// updates and closures the server pushes.
//
// ```
// ← {"k":"hello","connection":"<id>"}                  on open
// → {"k":"auth","token":"…"} / {"k":"auth"}            first, and after sign-in/out
// ← {"k":"authed","account":7} / {"k":"authed","rejected":true} / {"k":"authed"}
// → {"k":"sub","ch":"bookings:7"} / {"k":"unsub","ch":"…"}
// ← {"k":"subok","ch":"…"} / {"k":"subno","ch":"…", …}
// ← {"k":"upd","ch":"schedule","updates":{<transport>}}
// ← {"k":"closed","ch":"…"}
// ```

// ---------------------------------------------------------------------------
// Client → server
// ---------------------------------------------------------------------------

/// A message from a client to its server over the live socket.
sealed class DwClientMessage {
  const DwClientMessage();

  Map<String, Object?> toJson();

  /// Reads a client message. Throws [FormatException] for an unknown kind, a
  /// missing field or a key the kind does not define.
  factory DwClientMessage.fromJson(Object? json) {
    const what = 'A client message';
    final map = dwReadMap(json, what);
    return switch (map['k']) {
      'auth' => () {
        dwRejectUnknownKeys(map, const {'k', 'token'}, what);
        return DwAuthenticateMessage(
          dwReadOptionalString(map['token'], 'The token'),
        );
      }(),
      'sub' => DwSubscribeMessage(_channel(map, what)),
      'unsub' => DwUnsubscribeMessage(_channel(map, what)),
      final kind => throw FormatException(
        'Unknown client message kind "$kind"',
      ),
    };
  }
}

/// Binds the connection to a session token, or unbinds it (`null`).
///
/// Sent first on every (re)connection, and after sign-in and sign-out. The
/// server answers [DwAuthenticatedMessage].
final class DwAuthenticateMessage extends DwClientMessage {
  const DwAuthenticateMessage(this.token);

  final String? token;

  @override
  Map<String, Object?> toJson() => {'k': 'auth', 'token': ?token};
}

/// Subscribes the connection to a channel (its wire name, `chat:7`).
final class DwSubscribeMessage extends DwClientMessage {
  const DwSubscribeMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson() => {'k': 'sub', 'ch': channel};
}

/// Releases a channel subscription.
final class DwUnsubscribeMessage extends DwClientMessage {
  const DwUnsubscribeMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson() => {'k': 'unsub', 'ch': channel};
}

// ---------------------------------------------------------------------------
// Server → client
// ---------------------------------------------------------------------------

/// A message from the server to a client over the live socket.
sealed class DwServerMessage {
  const DwServerMessage();

  Map<String, Object?> toJson();

  /// Reads a server message; an update's transport is decoded with
  /// [protocol]. Throws [FormatException] for an unknown kind, a missing field
  /// or a key the kind does not define.
  factory DwServerMessage.fromJson(Object? json, DwProtocol protocol) {
    const what = 'A server message';
    final map = dwReadMap(json, what);
    switch (map['k']) {
      case 'hello':
        dwRejectUnknownKeys(map, const {'k', 'connection'}, what);
        return DwHelloMessage(
          dwReadString(map['connection'], 'The connection id'),
        );
      case 'authed':
        dwRejectUnknownKeys(map, const {'k', 'account', 'rejected'}, what);
        final account = map['account'];
        final rejected = map['rejected'];
        return switch ((account, rejected)) {
          (null, null) => const DwAuthenticatedMessage.anonymous(),
          (final int id, null) => DwAuthenticatedMessage.account(id),
          (null, true) => const DwAuthenticatedMessage.rejected(),
          _ => throw FormatException(
            'An authentication answer carries an account or a rejection: $map',
          ),
        };
      case 'subok':
        return DwSubscribedMessage(_channel(map, what));
      case 'subno':
        dwRejectUnknownKeys(map, const {'k', 'ch', 'r', 'x'}, what);
        return DwSubscriptionRefusedMessage._fromJson(map);
      case 'upd':
        dwRejectUnknownKeys(map, const {'k', 'ch', 'updates'}, what);
        return DwUpdateMessage(
          channel: dwReadString(map['ch'], 'The channel'),
          updates: DwTransport.fromJson(map['updates'], protocol),
        );
      case 'closed':
        return DwChannelClosedMessage(_channel(map, what));
      case final kind:
        throw FormatException('Unknown server message kind "$kind"');
    }
  }
}

/// The first message on a live connection: the id the client names it by in
/// `Dw-Live-Connection`, so the updates of its own calls come back in the
/// call's response instead of over the socket.
final class DwHelloMessage extends DwServerMessage {
  const DwHelloMessage(this.connectionId);

  final String connectionId;

  @override
  Map<String, Object?> toJson() => {'k': 'hello', 'connection': connectionId};
}

/// The answer to [DwAuthenticateMessage]: the account the connection now acts
/// for, anonymous, or a rejected token. The constructors are the only way to
/// build it, so an account and a rejection never come together.
final class DwAuthenticatedMessage extends DwServerMessage {
  const DwAuthenticatedMessage.account(int this.accountId) : rejected = false;

  /// No token was sent; the connection is anonymous.
  const DwAuthenticatedMessage.anonymous() : accountId = null, rejected = false;

  /// The token was not valid (revoked, unknown). The client drops it.
  const DwAuthenticatedMessage.rejected() : accountId = null, rejected = true;

  /// The account the connection now acts for; `null` when anonymous or
  /// rejected.
  final int? accountId;

  final bool rejected;

  @override
  Map<String, Object?> toJson() => {
    'k': 'authed',
    'account': ?accountId,
    if (rejected) 'rejected': true,
  };
}

/// The subscription is active.
final class DwSubscribedMessage extends DwServerMessage {
  const DwSubscribedMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson() => {'k': 'subok', 'ch': channel};
}

/// The subscription did not happen, for one of three reasons — the three a
/// call can end with short of success:
///
/// - [DwSubscriptionRefusedMessage.refused]: a [refusal] (`dw.forbidden`,
///   `dw.unknownChannel`, `dw.invalid` on field `channel`);
/// - [DwSubscriptionRefusedMessage.unauthenticated]: the connection has no
///   account, and every subscription needs one;
/// - [DwSubscriptionRefusedMessage.failed]: the server's check threw. An
///   incident, not a refusal — see the note on `DwCoreRefusal`.
///
/// At most one of [refusal] and [incidentId] is set; the constructors are the
/// only way to build the message, so no fourth state exists.
final class DwSubscriptionRefusedMessage extends DwServerMessage {
  const DwSubscriptionRefusedMessage.refused(
    this.channel,
    DwRefusal this.refusal,
  ) : incidentId = null;

  const DwSubscriptionRefusedMessage.unauthenticated(this.channel)
    : refusal = null,
      incidentId = null;

  const DwSubscriptionRefusedMessage.failed(
    this.channel,
    String this.incidentId,
  ) : refusal = null;

  factory DwSubscriptionRefusedMessage._fromJson(Map<String, Object?> json) {
    final channel = dwReadString(json['ch'], 'The channel');
    return switch ((json['r'], json['x'])) {
      (null, null) => DwSubscriptionRefusedMessage.unauthenticated(channel),
      (final Map<String, Object?> r, null) =>
        DwSubscriptionRefusedMessage.refused(channel, DwRefusal.fromJson(r)),
      (null, final String x) => DwSubscriptionRefusedMessage.failed(channel, x),
      _ => throw FormatException(
        'A subscription refusal carries either a refusal or an incident: $json',
      ),
    };
  }

  final String channel;
  final DwRefusal? refusal;

  /// What the operator finds the failed check by.
  final String? incidentId;

  bool get isUnauthenticated => refusal == null && incidentId == null;

  @override
  Map<String, Object?> toJson() => {
    'k': 'subno',
    'ch': channel,
    if (refusal != null) 'r': refusal!.toJson(),
    'x': ?incidentId,
  };
}

/// What one command published to a channel, in one message.
///
/// Not sent to the connection named in the command's `Dw-Live-Connection`:
/// it has the same updates in the command's response.
final class DwUpdateMessage extends DwServerMessage {
  const DwUpdateMessage({required this.channel, required this.updates});

  final String channel;

  final DwTransport updates;

  @override
  Map<String, Object?> toJson() => {
    'k': 'upd',
    'ch': channel,
    'updates': updates.toJson(),
  };
}

/// The server closed the subscription: access was revoked. Terminal — the
/// client does not resubscribe on its own.
final class DwChannelClosedMessage extends DwServerMessage {
  const DwChannelClosedMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson() => {'k': 'closed', 'ch': channel};
}

String _channel(Map<String, Object?> map, String what) {
  dwRejectUnknownKeys(map, const {'k', 'ch'}, what);
  return dwReadString(map['ch'], 'The channel');
}
