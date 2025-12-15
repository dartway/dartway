/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class DwChatReadMessageEvent
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DwChatReadMessageEvent._({
    required this.userId,
    required this.messageId,
  });

  factory DwChatReadMessageEvent({
    required int userId,
    required int messageId,
  }) = _DwChatReadMessageEventImpl;

  factory DwChatReadMessageEvent.fromJson(
      Map<String, dynamic> jsonSerialization) {
    return DwChatReadMessageEvent(
      userId: jsonSerialization['userId'] as int,
      messageId: jsonSerialization['messageId'] as int,
    );
  }

  int userId;

  int messageId;

  /// Returns a shallow copy of this [DwChatReadMessageEvent]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatReadMessageEvent copyWith({
    int? userId,
    int? messageId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'messageId': messageId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      'userId': userId,
      'messageId': messageId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DwChatReadMessageEventImpl extends DwChatReadMessageEvent {
  _DwChatReadMessageEventImpl({
    required int userId,
    required int messageId,
  }) : super._(
          userId: userId,
          messageId: messageId,
        );

  /// Returns a shallow copy of this [DwChatReadMessageEvent]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatReadMessageEvent copyWith({
    int? userId,
    int? messageId,
  }) {
    return DwChatReadMessageEvent(
      userId: userId ?? this.userId,
      messageId: messageId ?? this.messageId,
    );
  }
}
