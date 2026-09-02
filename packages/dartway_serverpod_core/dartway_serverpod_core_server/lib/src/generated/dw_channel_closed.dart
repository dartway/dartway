/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'dw_channel_closed_reason.dart' as _i2;

/// The server ended a channel subscription on purpose. Travels to the client so
/// it can tell a refusal from a dropped connection: one must not be retried,
/// the other must.
abstract class DwChannelClosed
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  DwChannelClosed._({
    required this.channel,
    required this.reason,
  });

  factory DwChannelClosed({
    required String channel,
    required _i2.DwChannelClosedReason reason,
  }) = _DwChannelClosedImpl;

  factory DwChannelClosed.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChannelClosed(
      channel: jsonSerialization['channel'] as String,
      reason: _i2.DwChannelClosedReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  String channel;

  _i2.DwChannelClosedReason reason;

  /// Returns a shallow copy of this [DwChannelClosed]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChannelClosed copyWith({
    String? channel,
    _i2.DwChannelClosedReason? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_serverpod_core.DwChannelClosed',
      'channel': channel,
      'reason': reason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'dartway_serverpod_core.DwChannelClosed',
      'channel': channel,
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'DwChannelClosed(channel: $channel, reason: $reason)';
  }
}

class _DwChannelClosedImpl extends DwChannelClosed {
  _DwChannelClosedImpl({
    required String channel,
    required _i2.DwChannelClosedReason reason,
  }) : super._(
         channel: channel,
         reason: reason,
       );

  /// Returns a shallow copy of this [DwChannelClosed]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChannelClosed copyWith({
    String? channel,
    _i2.DwChannelClosedReason? reason,
  }) {
    return DwChannelClosed(
      channel: channel ?? this.channel,
      reason: reason ?? this.reason,
    );
  }
}
