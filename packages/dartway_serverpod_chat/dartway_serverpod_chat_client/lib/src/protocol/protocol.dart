/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as _i9;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

import 'dw_chat_channel.dart' as _i2;
import 'dw_chat_custom_message_type.dart' as _i3;
import 'dw_chat_initial_data.dart' as _i4;
import 'dw_chat_message.dart' as _i5;
import 'dw_chat_participant.dart' as _i6;
import 'dw_chat_read_message_event.dart' as _i7;
import 'dw_chat_typing_message_event.dart' as _i8;

export 'client.dart';
export 'dw_chat_channel.dart';
export 'dw_chat_custom_message_type.dart';
export 'dw_chat_initial_data.dart';
export 'dw_chat_message.dart';
export 'dw_chat_participant.dart';
export 'dw_chat_read_message_event.dart';
export 'dw_chat_typing_message_event.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (t == _i2.DwChatChannel) {
      return _i2.DwChatChannel.fromJson(data) as T;
    }
    if (t == _i3.DwChatCustomMessageType) {
      return _i3.DwChatCustomMessageType.fromJson(data) as T;
    }
    if (t == _i4.DwChatInitialData) {
      return _i4.DwChatInitialData.fromJson(data) as T;
    }
    if (t == _i5.DwChatMessage) {
      return _i5.DwChatMessage.fromJson(data) as T;
    }
    if (t == _i6.DwChatParticipant) {
      return _i6.DwChatParticipant.fromJson(data) as T;
    }
    if (t == _i7.DwChatReadMessageEvent) {
      return _i7.DwChatReadMessageEvent.fromJson(data) as T;
    }
    if (t == _i8.DwChatTypingMessageEvent) {
      return _i8.DwChatTypingMessageEvent.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.DwChatChannel?>()) {
      return (data != null ? _i2.DwChatChannel.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.DwChatCustomMessageType?>()) {
      return (data != null ? _i3.DwChatCustomMessageType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i4.DwChatInitialData?>()) {
      return (data != null ? _i4.DwChatInitialData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DwChatMessage?>()) {
      return (data != null ? _i5.DwChatMessage.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.DwChatParticipant?>()) {
      return (data != null ? _i6.DwChatParticipant.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DwChatReadMessageEvent?>()) {
      return (data != null ? _i7.DwChatReadMessageEvent.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i8.DwChatTypingMessageEvent?>()) {
      return (data != null ? _i8.DwChatTypingMessageEvent.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<List<_i6.DwChatParticipant>?>()) {
      return (data != null
              ? (data as List)
                  .map((e) => deserialize<_i6.DwChatParticipant>(e))
                  .toList()
              : null)
          as T;
    }
    if (t == List<_i5.DwChatMessage>) {
      return (data as List)
              .map((e) => deserialize<_i5.DwChatMessage>(e))
              .toList()
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == _i1.getType<List<int>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<int>(e)).toList()
              : null)
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    try {
      return _i9.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i2.DwChatChannel) {
      return 'DwChatChannel';
    }
    if (data is _i3.DwChatCustomMessageType) {
      return 'DwChatCustomMessageType';
    }
    if (data is _i4.DwChatInitialData) {
      return 'DwChatInitialData';
    }
    if (data is _i5.DwChatMessage) {
      return 'DwChatMessage';
    }
    if (data is _i6.DwChatParticipant) {
      return 'DwChatParticipant';
    }
    if (data is _i7.DwChatReadMessageEvent) {
      return 'DwChatReadMessageEvent';
    }
    if (data is _i8.DwChatTypingMessageEvent) {
      return 'DwChatTypingMessageEvent';
    }
    className = _i9.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_serverpod_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'DwChatChannel') {
      return deserialize<_i2.DwChatChannel>(data['data']);
    }
    if (dataClassName == 'DwChatCustomMessageType') {
      return deserialize<_i3.DwChatCustomMessageType>(data['data']);
    }
    if (dataClassName == 'DwChatInitialData') {
      return deserialize<_i4.DwChatInitialData>(data['data']);
    }
    if (dataClassName == 'DwChatMessage') {
      return deserialize<_i5.DwChatMessage>(data['data']);
    }
    if (dataClassName == 'DwChatParticipant') {
      return deserialize<_i6.DwChatParticipant>(data['data']);
    }
    if (dataClassName == 'DwChatReadMessageEvent') {
      return deserialize<_i7.DwChatReadMessageEvent>(data['data']);
    }
    if (dataClassName == 'DwChatTypingMessageEvent') {
      return deserialize<_i8.DwChatTypingMessageEvent>(data['data']);
    }
    if (dataClassName.startsWith('dartway_serverpod_core.')) {
      data['className'] = dataClassName.substring(23);
      return _i9.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }
}
