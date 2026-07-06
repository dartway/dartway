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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import '../chat/chat_channel.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import 'package:dartway_example_client/src/protocol/protocol.dart' as _i4;

abstract class ChatMessage implements _i1.SerializableModel {
  ChatMessage._({
    this.id,
    required this.channelId,
    this.channel,
    required this.authorProfileId,
    this.authorProfile,
    required this.messageText,
    required this.createdAt,
  });

  factory ChatMessage({
    int? id,
    required int channelId,
    _i2.ChatChannel? channel,
    required int authorProfileId,
    _i3.UserProfile? authorProfile,
    required String messageText,
    required DateTime createdAt,
  }) = _ChatMessageImpl;

  factory ChatMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChatMessage(
      id: jsonSerialization['id'] as int?,
      channelId: jsonSerialization['channelId'] as int,
      channel: jsonSerialization['channel'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.ChatChannel>(
              jsonSerialization['channel'],
            ),
      authorProfileId: jsonSerialization['authorProfileId'] as int,
      authorProfile: jsonSerialization['authorProfile'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['authorProfile'],
            ),
      messageText: jsonSerialization['messageText'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int channelId;

  _i2.ChatChannel? channel;

  int authorProfileId;

  _i3.UserProfile? authorProfile;

  String messageText;

  DateTime createdAt;

  /// Returns a shallow copy of this [ChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChatMessage copyWith({
    int? id,
    int? channelId,
    _i2.ChatChannel? channel,
    int? authorProfileId,
    _i3.UserProfile? authorProfile,
    String? messageText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChatMessage',
      if (id != null) 'id': id,
      'channelId': channelId,
      if (channel != null) 'channel': channel?.toJson(),
      'authorProfileId': authorProfileId,
      if (authorProfile != null) 'authorProfile': authorProfile?.toJson(),
      'messageText': messageText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChatMessageImpl extends ChatMessage {
  _ChatMessageImpl({
    int? id,
    required int channelId,
    _i2.ChatChannel? channel,
    required int authorProfileId,
    _i3.UserProfile? authorProfile,
    required String messageText,
    required DateTime createdAt,
  }) : super._(
         id: id,
         channelId: channelId,
         channel: channel,
         authorProfileId: authorProfileId,
         authorProfile: authorProfile,
         messageText: messageText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChatMessage copyWith({
    Object? id = _Undefined,
    int? channelId,
    Object? channel = _Undefined,
    int? authorProfileId,
    Object? authorProfile = _Undefined,
    String? messageText,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id is int? ? id : this.id,
      channelId: channelId ?? this.channelId,
      channel: channel is _i2.ChatChannel? ? channel : this.channel?.copyWith(),
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorProfile: authorProfile is _i3.UserProfile?
          ? authorProfile
          : this.authorProfile?.copyWith(),
      messageText: messageText ?? this.messageText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
