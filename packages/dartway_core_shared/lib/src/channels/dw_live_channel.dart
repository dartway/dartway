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
final class DwLiveChannel {
  const DwLiveChannel(this.kind, [this.key]);

  final DwChannelKind kind;

  /// An `int` or a `String` identifying the instance, or `null` for a kind
  /// with a single instance.
  final Object? key;

  /// The channel's name on the wire: `chat:7`, or `news`.
  String get wireName =>
      key == null ? kind.channelName : '${kind.channelName}:$key';

  @override
  bool operator ==(Object other) =>
      other is DwLiveChannel && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => 'DwLiveChannel($wireName)';
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
