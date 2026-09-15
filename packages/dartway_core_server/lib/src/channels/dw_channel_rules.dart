import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';
import 'dw_channel_rule.dart';

/// The server's channel rules by kind: the one place a channel name is
/// resolved and access to it decided — for a subscription, and for a
/// command's response, which carries what its caller may read.
@internal
final class DwChannelRules {
  DwChannelRules(Iterable<DwChannelRule> rules)
    : _byKind = {for (final rule in rules) rule.kind.channelName: rule};

  static final DwChannelRules none = DwChannelRules(const []);

  final Map<String, DwChannelRule> _byKind;

  /// Resolves a wire channel name: its rule and the channel it names.
  DwChannelLookup lookUp(String wireName) {
    final parsed = dwParseChannelName(wireName);
    final rule = _byKind[parsed.kind];
    if (rule == null) return const DwUnknownChannel();
    final DwLiveChannel? channel = switch (rule) {
      DwKeyedChannelRule() =>
        parsed.key == null ? null : rule.channelFor(parsed.key!),
      DwSingleChannelRule() =>
        parsed.key == null ? DwLiveChannel(rule.kind) : null,
    };
    return channel == null
        ? const DwInvalidChannel()
        : DwKnownChannel(rule, channel);
  }

  /// Why a server may not publish to [channel], or `null` when it may: its
  /// kind has a rule, and the channel is one a subscriber could name. Anything
  /// else could never be heard — no subscription resolves to it.
  String? publishProblem(DwLiveChannel channel) =>
      switch (lookUp(channel.wireName)) {
        DwKnownChannel() => null,
        DwUnknownChannel() =>
          'No channel rule declares the kind "${channel.kind.channelName}": '
              'add one to DwAppServer(channels:)',
        DwInvalidChannel() =>
          'The rule of "${channel.kind.channelName}" does not accept the '
              'channel "${channel.wireName}": a keyed kind needs its key in '
              'canonical form, a single kind none',
      };
}

/// What a wire channel name resolves to.
@internal
sealed class DwChannelLookup {
  const DwChannelLookup();
}

/// No rule declares the kind.
@internal
final class DwUnknownChannel extends DwChannelLookup {
  const DwUnknownChannel();
}

/// The kind has a rule that does not accept the key (or its absence).
@internal
final class DwInvalidChannel extends DwChannelLookup {
  const DwInvalidChannel();
}

@internal
final class DwKnownChannel extends DwChannelLookup {
  const DwKnownChannel(this.rule, this.channel);

  final DwChannelRule rule;
  final DwLiveChannel channel;

  /// Whether the caller of [ctx] may read the channel. Rules run for an
  /// account only (D-020): the caller of [ctx] must be signed in.
  Future<bool> allows(DwCallContext ctx) => switch (rule) {
    final DwKeyedChannelRule<Object> keyed => keyed.canSubscribe(ctx, channel),
    final DwSingleChannelRule single => single.canSubscribe(ctx),
  };
}
