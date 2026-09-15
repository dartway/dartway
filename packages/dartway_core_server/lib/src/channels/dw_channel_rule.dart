import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../context/dw_call_context.dart';

/// Who may read a channel kind, declared once per kind.
///
/// Asked when a connection subscribes, and — for every channel a successful
/// command publishes to that the caller's named connection is not subscribed
/// to — whether the command's response carries it (D-053). So a rule answers
/// "may this account read this channel" for any caller, not only for the
/// screen that subscribes.
///
/// A kind without a rule refuses every subscription with `dw.unknownChannel`,
/// and publishing to it throws. Rules run for accounts only (D-020): an
/// anonymous connection is answered "not authenticated", and an anonymous
/// caller's response carries no updates.
///
/// A subscription is checked once; a command that takes access away revokes
/// it (`ctx.revoke`).
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

  /// A kind keyed by the account of its subscriber (`bookings:7`): the
  /// server side of `DwLiveChannel.ofCaller` (D-037). A connection may
  /// subscribe to its own account's key only; any other key is refused with
  /// `dw.forbidden`, and a key that is not a canonical account id with
  /// `dw.invalid`.
  ///
  /// Publish to it with `DwLiveChannel.forAccount(kind, accountId)`.
  static DwChannelRule ofCaller(DwChannelKind kind) =>
      DwKeyedChannelRule<int>._(
        kind,
        int.parse,
        (ctx, accountId) async => ctx.accountId == accountId,
      );

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
