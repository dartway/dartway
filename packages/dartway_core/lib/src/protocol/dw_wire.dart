import '../dto/dw_command.dart';
import '../dto/dw_dto.dart';
import '../dto/dw_request.dart';
import '../result/dw_refusal.dart';
import 'dw_protocol.dart';

/// The version of the wire protocol. A client and a server with different
/// versions refuse each other at connection, loudly.
const int dwWireVersion = 1;

// ---------------------------------------------------------------------------
// Client → server
// ---------------------------------------------------------------------------

/// A message from a client to its server over the app WebSocket.
sealed class DwClientMessage {
  const DwClientMessage();

  Map<String, Object?> toJson(DwProtocol protocol);

  static DwClientMessage fromJson(
    Map<String, Object?> json,
    DwProtocol protocol,
  ) => switch (json['k']) {
    'auth' => DwAuthenticateMessage(json['token'] as String?),
    'req' => DwRequestMessage(
      id: json['id']! as int,
      request: protocol.decodeTagged(json['dto']) as DwRequest<Object?>,
      page: DwPageParams.fromJson(json['page']),
    ),
    'cmd' => DwCommandMessage(
      id: json['id']! as int,
      idempotencyKey: json['key']! as String,
      command: protocol.decodeTagged(json['dto']) as DwCommand<Object?>,
    ),
    'sub' => DwSubscribeMessage(json['ch']! as String),
    'unsub' => DwUnsubscribeMessage(json['ch']! as String),
    final kind => throw FormatException('Unknown client message kind "$kind"'),
  };
}

/// Binds the connection to a session token, or unbinds it (`null`).
///
/// Sent first on every (re)connection that has a token, and after sign-in and
/// sign-out. The server answers [DwAuthenticatedMessage].
final class DwAuthenticateMessage extends DwClientMessage {
  const DwAuthenticateMessage(this.token);

  final String? token;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'auth',
    if (token != null) 'token': token,
  };
}

/// Runs a request.
final class DwRequestMessage extends DwClientMessage {
  const DwRequestMessage({required this.id, required this.request, this.page});

  final int id;
  final DwRequest<Object?> request;
  final DwPageParams? page;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'req',
    'id': id,
    'dto': protocol.encodeTagged(request),
    if (page != null) 'page': page!.toJson(),
  };
}

/// Runs a command.
final class DwCommandMessage extends DwClientMessage {
  const DwCommandMessage({
    required this.id,
    required this.idempotencyKey,
    required this.command,
  });

  final int id;
  final String idempotencyKey;
  final DwCommand<Object?> command;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'cmd',
    'id': id,
    'key': idempotencyKey,
    'dto': protocol.encodeTagged(command),
  };
}

/// Subscribes the connection to a channel.
final class DwSubscribeMessage extends DwClientMessage {
  const DwSubscribeMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'sub',
    'ch': channel,
  };
}

/// Releases a channel subscription.
final class DwUnsubscribeMessage extends DwClientMessage {
  const DwUnsubscribeMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'unsub',
    'ch': channel,
  };
}

// ---------------------------------------------------------------------------
// Server → client
// ---------------------------------------------------------------------------

/// A message from the server to a client.
sealed class DwServerMessage {
  const DwServerMessage();

  Map<String, Object?> toJson(DwProtocol protocol);

  static DwServerMessage fromJson(
    Map<String, Object?> json,
    DwProtocol protocol,
  ) => switch (json['k']) {
    'authed' => DwAuthenticatedMessage(
      accountId: json['account'] as int?,
      rejected: json['rejected'] == true,
    ),
    'res' => DwResultMessage(
      id: json['id']! as int,
      status: DwResultStatus.values.byName(json['s']! as String),
      value: json['v'],
      refusal: json['r'] == null
          ? null
          : DwRefusal.fromJson(json['r']! as Map<String, Object?>),
      incidentId: json['x'] as String?,
    ),
    'upd' => DwUpdateMessage(
      channel: json['ch']! as String,
      items: [
        for (final item in json['items']! as List<Object?>)
          protocol.decodeTagged(item),
      ],
    ),
    'subok' => DwSubscribedMessage(json['ch']! as String),
    'subno' => DwSubscriptionRefusedMessage._fromJson(json),
    'closed' => DwChannelClosedMessage(json['ch']! as String),
    final kind => throw FormatException('Unknown server message kind "$kind"'),
  };
}

/// The answer to [DwAuthenticateMessage].
final class DwAuthenticatedMessage extends DwServerMessage {
  const DwAuthenticatedMessage({this.accountId, this.rejected = false});

  /// The account the connection now acts for; `null` when anonymous.
  final int? accountId;

  /// The token was not valid (expired, revoked, unknown). The client drops it.
  final bool rejected;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'authed',
    if (accountId != null) 'account': accountId,
    if (rejected) 'rejected': true,
  };
}

/// How a call ended, on the wire.
enum DwResultStatus { ok, refused, unauthenticated, failed }

/// The answer to a request or a command. [value] is already encoded by the
/// request or command class; the client decodes it with the same class.
final class DwResultMessage extends DwServerMessage {
  const DwResultMessage({
    required this.id,
    required this.status,
    this.value,
    this.refusal,
    this.incidentId,
  });

  final int id;
  final DwResultStatus status;
  final Object? value;
  final DwRefusal? refusal;
  final String? incidentId;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'res',
    'id': id,
    's': status.name,
    if (value != null) 'v': value,
    if (refusal != null) 'r': refusal!.toJson(),
    if (incidentId != null) 'x': incidentId,
  };
}

/// Objects published to a channel by one command, in one message.
final class DwUpdateMessage extends DwServerMessage {
  const DwUpdateMessage({required this.channel, required this.items});

  final String channel;

  /// Data objects and [DwDeleted] notices.
  final List<DwDto> items;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'upd',
    'ch': channel,
    'items': [for (final item in items) protocol.encodeTagged(item)],
  };
}

/// The subscription is active.
final class DwSubscribedMessage extends DwServerMessage {
  const DwSubscribedMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'subok',
    'ch': channel,
  };
}

/// The subscription did not happen, for one of three reasons — the same
/// three a call can end with short of success, encoded as a result message
/// encodes them:
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
    final channel = json['ch']! as String;
    final refusal = json['r'];
    final incident = json['x'];
    return switch ((refusal, incident)) {
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
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'subno',
    'ch': channel,
    if (refusal != null) 'r': refusal!.toJson(),
    if (incidentId != null) 'x': incidentId,
  };
}

/// The server closed the subscription: access was revoked. Terminal — the
/// client does not resubscribe on its own.
final class DwChannelClosedMessage extends DwServerMessage {
  const DwChannelClosedMessage(this.channel);

  final String channel;

  @override
  Map<String, Object?> toJson(DwProtocol protocol) => {
    'k': 'closed',
    'ch': channel,
  };
}
