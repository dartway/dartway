/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dw_chat_message.dart' as _i2;

abstract class DwChatInitialData implements _i1.SerializableModel {
  DwChatInitialData._({
    required this.messages,
    required this.participantIds,
    this.lastReadMessageId,
  });

  factory DwChatInitialData({
    required List<_i2.DwChatMessage> messages,
    required List<int> participantIds,
    int? lastReadMessageId,
  }) = _DwChatInitialDataImpl;

  factory DwChatInitialData.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChatInitialData(
      messages: (jsonSerialization['messages'] as List)
          .map((e) => _i2.DwChatMessage.fromJson((e as Map<String, dynamic>)))
          .toList(),
      participantIds: (jsonSerialization['participantIds'] as List)
          .map((e) => e as int)
          .toList(),
      lastReadMessageId: jsonSerialization['lastReadMessageId'] as int?,
    );
  }

  List<_i2.DwChatMessage> messages;

  List<int> participantIds;

  int? lastReadMessageId;

  /// Returns a shallow copy of this [DwChatInitialData]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatInitialData copyWith({
    List<_i2.DwChatMessage>? messages,
    List<int>? participantIds,
    int? lastReadMessageId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      'messages': messages.toJson(valueToJson: (v) => v.toJson()),
      'participantIds': participantIds.toJson(),
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatInitialDataImpl extends DwChatInitialData {
  _DwChatInitialDataImpl({
    required List<_i2.DwChatMessage> messages,
    required List<int> participantIds,
    int? lastReadMessageId,
  }) : super._(
          messages: messages,
          participantIds: participantIds,
          lastReadMessageId: lastReadMessageId,
        );

  /// Returns a shallow copy of this [DwChatInitialData]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatInitialData copyWith({
    List<_i2.DwChatMessage>? messages,
    List<int>? participantIds,
    Object? lastReadMessageId = _Undefined,
  }) {
    return DwChatInitialData(
      messages: messages ?? this.messages.map((e0) => e0.copyWith()).toList(),
      participantIds:
          participantIds ?? this.participantIds.map((e0) => e0).toList(),
      lastReadMessageId: lastReadMessageId is int?
          ? lastReadMessageId
          : this.lastReadMessageId,
    );
  }
}
