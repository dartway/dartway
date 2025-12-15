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
import 'dw_chat_channel.dart' as _i2;
import 'dw_chat_message.dart' as _i3;

abstract class DwChatParticipant implements _i1.SerializableModel {
  DwChatParticipant._({
    this.id,
    required this.userId,
    required this.chatChannelId,
    this.chatChannel,
    this.lastMessageId,
    this.lastMessage,
    this.lastMessageSentAt,
    int? unreadCount,
    this.lastReadMessageId,
    this.lastReadMessage,
    bool? isDeleted,
  })  : unreadCount = unreadCount ?? 0,
        isDeleted = isDeleted ?? false;

  factory DwChatParticipant({
    int? id,
    required int userId,
    required int chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  }) = _DwChatParticipantImpl;

  factory DwChatParticipant.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChatParticipant(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      chatChannelId: jsonSerialization['chatChannelId'] as int,
      chatChannel: jsonSerialization['chatChannel'] == null
          ? null
          : _i2.DwChatChannel.fromJson(
              (jsonSerialization['chatChannel'] as Map<String, dynamic>)),
      lastMessageId: jsonSerialization['lastMessageId'] as int?,
      lastMessage: jsonSerialization['lastMessage'] == null
          ? null
          : _i3.DwChatMessage.fromJson(
              (jsonSerialization['lastMessage'] as Map<String, dynamic>)),
      lastMessageSentAt: jsonSerialization['lastMessageSentAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastMessageSentAt']),
      unreadCount: jsonSerialization['unreadCount'] as int,
      lastReadMessageId: jsonSerialization['lastReadMessageId'] as int?,
      lastReadMessage: jsonSerialization['lastReadMessage'] == null
          ? null
          : _i3.DwChatMessage.fromJson(
              (jsonSerialization['lastReadMessage'] as Map<String, dynamic>)),
      isDeleted: jsonSerialization['isDeleted'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  int chatChannelId;

  _i2.DwChatChannel? chatChannel;

  int? lastMessageId;

  _i3.DwChatMessage? lastMessage;

  DateTime? lastMessageSentAt;

  int unreadCount;

  int? lastReadMessageId;

  _i3.DwChatMessage? lastReadMessage;

  bool isDeleted;

  /// Returns a shallow copy of this [DwChatParticipant]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatParticipant copyWith({
    int? id,
    int? userId,
    int? chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'chatChannelId': chatChannelId,
      if (chatChannel != null) 'chatChannel': chatChannel?.toJson(),
      if (lastMessageId != null) 'lastMessageId': lastMessageId,
      if (lastMessage != null) 'lastMessage': lastMessage?.toJson(),
      if (lastMessageSentAt != null)
        'lastMessageSentAt': lastMessageSentAt?.toJson(),
      'unreadCount': unreadCount,
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      if (lastReadMessage != null) 'lastReadMessage': lastReadMessage?.toJson(),
      'isDeleted': isDeleted,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatParticipantImpl extends DwChatParticipant {
  _DwChatParticipantImpl({
    int? id,
    required int userId,
    required int chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  }) : super._(
          id: id,
          userId: userId,
          chatChannelId: chatChannelId,
          chatChannel: chatChannel,
          lastMessageId: lastMessageId,
          lastMessage: lastMessage,
          lastMessageSentAt: lastMessageSentAt,
          unreadCount: unreadCount,
          lastReadMessageId: lastReadMessageId,
          lastReadMessage: lastReadMessage,
          isDeleted: isDeleted,
        );

  /// Returns a shallow copy of this [DwChatParticipant]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatParticipant copyWith({
    Object? id = _Undefined,
    int? userId,
    int? chatChannelId,
    Object? chatChannel = _Undefined,
    Object? lastMessageId = _Undefined,
    Object? lastMessage = _Undefined,
    Object? lastMessageSentAt = _Undefined,
    int? unreadCount,
    Object? lastReadMessageId = _Undefined,
    Object? lastReadMessage = _Undefined,
    bool? isDeleted,
  }) {
    return DwChatParticipant(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      chatChannelId: chatChannelId ?? this.chatChannelId,
      chatChannel: chatChannel is _i2.DwChatChannel?
          ? chatChannel
          : this.chatChannel?.copyWith(),
      lastMessageId: lastMessageId is int? ? lastMessageId : this.lastMessageId,
      lastMessage: lastMessage is _i3.DwChatMessage?
          ? lastMessage
          : this.lastMessage?.copyWith(),
      lastMessageSentAt: lastMessageSentAt is DateTime?
          ? lastMessageSentAt
          : this.lastMessageSentAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId is int?
          ? lastReadMessageId
          : this.lastReadMessageId,
      lastReadMessage: lastReadMessage is _i3.DwChatMessage?
          ? lastReadMessage
          : this.lastReadMessage?.copyWith(),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
