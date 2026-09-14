/// A kind of realtime channel. The project declares its kinds as an enum in its
/// shared package:
///
/// ```dart
/// enum AppChannel with DwChannelKind { chat, myBookings, news }
/// ```
///
/// The server declares, once per kind, who may subscribe; a kind without a
/// declaration refuses every subscription.
mixin DwChannelKind on Enum {
  /// The kind's name on the wire. Must not contain `:`.
  String get channelName => name;
}

/// One channel: a kind and an optional key (`chat` + `7`).
///
/// A request declares the channels its state lives on, and a request is a
/// value of its own fields. "My bookings" is the one channel it cannot name
/// that way — its key is whoever is signed in, which is no field of the
/// request — so it declares [DwLiveChannel.ofCaller] and the client fills in
/// the account (D-037).
final class DwLiveChannel {
  const DwLiveChannel(this.kind, [this.key]) : isOfCaller = false;

  /// The instance of [kind] keyed by the account of whoever watches the
  /// request: `bookings:<account id>`.
  ///
  /// Declared by "my …" requests, which carry no account id. The client
  /// resolves it with [resolvedFor] when it subscribes — its state is scoped
  /// by account already — and the server's `DwChannelRule.ofCaller` lets a
  /// connection subscribe to its own account's key only. The server publishes
  /// to it by naming the account: [DwLiveChannel.forAccount].
  ///
  /// It has no [wireName] until resolved.
  const DwLiveChannel.ofCaller(this.kind) : key = null, isOfCaller = true;

  /// The instance of [kind] keyed by [accountId]: what a caller channel
  /// resolves to for that account, and what the server publishes to so that
  /// the account's "my …" requests hear it.
  const DwLiveChannel.forAccount(this.kind, int accountId)
    : key = accountId,
      isOfCaller = false;

  final DwChannelKind kind;

  /// An `int` or a `String` identifying the instance, or `null` for a kind
  /// with a single instance and for an unresolved caller channel.
  final Object? key;

  /// Whether this is [DwLiveChannel.ofCaller], keyed by an account not yet
  /// known.
  final bool isOfCaller;

  /// This channel as [accountId] listens to it: a caller channel becomes
  /// [DwLiveChannel.forAccount]; any other channel is itself.
  DwLiveChannel resolvedFor(int accountId) =>
      isOfCaller ? DwLiveChannel.forAccount(kind, accountId) : this;

  /// The channel's name on the wire: `chat:7`, or `news`. Throws [StateError]
  /// for a caller channel, whose key is not known until it is resolved for an
  /// account ([resolvedFor]).
  String get wireName {
    if (isOfCaller) {
      throw StateError(
        'DwLiveChannel.ofCaller(${kind.channelName}) has no wire name until '
        'it is resolved for an account (resolvedFor). A server publishes to '
        'DwLiveChannel.forAccount(${kind.channelName}, accountId).',
      );
    }
    return key == null ? kind.channelName : '${kind.channelName}:$key';
  }

  @override
  bool operator ==(Object other) =>
      other is DwLiveChannel &&
      other.kind == kind &&
      other.key == key &&
      other.isOfCaller == isOfCaller;

  @override
  int get hashCode => Object.hash(kind, key, isOfCaller);

  @override
  String toString() => isOfCaller
      ? 'DwLiveChannel.ofCaller(${kind.channelName})'
      : 'DwLiveChannel($wireName)';
}

/// Splits a wire channel name into its kind name and raw key.
({String kind, String? key}) dwParseChannelName(String wireName) {
  final index = wireName.indexOf(':');
  if (index < 0) return (kind: wireName, key: null);
  return (
    kind: wireName.substring(0, index),
    key: wireName.substring(index + 1),
  );
}
