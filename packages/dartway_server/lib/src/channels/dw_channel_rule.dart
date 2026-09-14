import 'package:dartway_core/dartway_core.dart';

import '../context/dw_call_context.dart';

/// Who may subscribe to a channel kind, declared once per kind.
///
/// A kind without a rule refuses every subscription with `dw.unknownChannel`.
/// Only signed-in connections subscribe (D-020): the check runs with an
/// account, and an anonymous connection is answered "not authenticated".
///
/// Access is checked once, at subscription; everything published to a channel
/// must be readable by every subscriber of it. A command that takes access
/// away revokes it (`ctx.revoke`).
sealed class DwChannelRule {
  const DwChannelRule._(this.kind);

  final DwChannelKind kind;

  /// A kind whose instances are told apart by a key (`chat:7`). [parseKey]
  /// turns the wire text into the key and throws on malformed input; the
  /// channel name must be canonical (`chat:7`, not `chat:07`).
  static DwChannelRule keyed<K extends Object>(
    DwChannelKind kind, {
    required K Function(String raw) parseKey,
    required Future<bool> Function(DwCallContext ctx, K key) canSubscribe,
  }) => DwKeyedChannelRule<K>._(kind, parseKey, canSubscribe);

  /// A kind with one instance (`news`).
  static DwChannelRule single(
    DwChannelKind kind, {
    required Future<bool> Function(DwCallContext ctx) canSubscribe,
  }) => DwSingleChannelRule._(kind, canSubscribe);
}

final class DwKeyedChannelRule<K extends Object> extends DwChannelRule {
  const DwKeyedChannelRule._(super.kind, this.parseKey, this._canSubscribe)
    : super._();

  final K Function(String raw) parseKey;
  final Future<bool> Function(DwCallContext ctx, K key) _canSubscribe;

  /// Parses [rawKey] into the channel; `null` when malformed or not canonical.
  DwLiveChannel? channelFor(String rawKey) {
    final K key;
    try {
      key = parseKey(rawKey);
    } catch (_) {
      return null;
    }
    final channel = DwLiveChannel(kind, key);
    return channel.wireName == '${kind.channelName}:$rawKey' ? channel : null;
  }

  Future<bool> canSubscribe(DwCallContext ctx, DwLiveChannel channel) =>
      _canSubscribe(ctx, channel.key! as K);
}

final class DwSingleChannelRule extends DwChannelRule {
  const DwSingleChannelRule._(super.kind, this._canSubscribe) : super._();

  final Future<bool> Function(DwCallContext ctx) _canSubscribe;

  Future<bool> canSubscribe(DwCallContext ctx) => _canSubscribe(ctx);
}
