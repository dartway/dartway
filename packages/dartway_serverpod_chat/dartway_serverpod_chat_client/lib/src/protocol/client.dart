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
import 'dart:async' as _i2;
import 'package:serverpod_serialization/src/serialization.dart' as _i3;

/// {@category Endpoint}
class EndpointChat extends _i1.EndpointRef {
  EndpointChat(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dartway_serverpod_chat.chat';

  _i2.Stream<_i3.SerializableModel> updatesStream({required int chatId}) =>
      caller.callStreamingServerEndpoint<
        _i2.Stream<_i3.SerializableModel>,
        _i3.SerializableModel
      >('dartway_serverpod_chat.chat', 'updatesStream', {'chatId': chatId}, {});

  _i2.Future<void> readChatMessages(List<int> readMessageIds, int chatId) =>
      caller.callServerEndpoint<void>(
        'dartway_serverpod_chat.chat',
        'readChatMessages',
        {'readMessageIds': readMessageIds, 'chatId': chatId},
      );

  _i2.Future<void> typingToggle(int channelId, bool isTyping) =>
      caller.callServerEndpoint<void>(
        'dartway_serverpod_chat.chat',
        'typingToggle',
        {'channelId': channelId, 'isTyping': isTyping},
      );
}

/// {@category Endpoint}
class EndpointModule extends _i1.EndpointRef {
  EndpointModule(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dartway_serverpod_chat.module';

  _i2.Future<String> hello(String name) => caller.callServerEndpoint<String>(
    'dartway_serverpod_chat.module',
    'hello',
    {'name': name},
  );
}

class Caller extends _i1.ModuleEndpointCaller {
  Caller(_i1.ServerpodClientShared client) : super(client) {
    chat = EndpointChat(this);
    module = EndpointModule(this);
  }

  late final EndpointChat chat;

  late final EndpointModule module;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'dartway_serverpod_chat.chat': chat,
    'dartway_serverpod_chat.module': module,
  };
}
