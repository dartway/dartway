/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    as _i4;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

import '../endpoints/chat_endpoint.dart' as _i2;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'chat': _i2.ChatEndpoint()
        ..initialize(server, 'chat', 'dartway_serverpod_chat'),
    };
    connectors['chat'] = _i1.EndpointConnector(
      name: 'chat',
      endpoint: endpoints['chat']!,
      methodConnectors: {
        'readChatMessages': _i1.MethodConnector(
          name: 'readChatMessages',
          params: {
            'readMessageIds': _i1.ParameterDescription(
              name: 'readMessageIds',
              type: _i1.getType<List<int>>(),
              nullable: false,
            ),
            'chatId': _i1.ParameterDescription(
              name: 'chatId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['chat'] as _i2.ChatEndpoint).readChatMessages(
            session,
            params['readMessageIds'],
            params['chatId'],
          ),
        ),
        'typingToggle': _i1.MethodConnector(
          name: 'typingToggle',
          params: {
            'channelId': _i1.ParameterDescription(
              name: 'channelId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'isTyping': _i1.ParameterDescription(
              name: 'isTyping',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['chat'] as _i2.ChatEndpoint).typingToggle(
            session,
            params['channelId'],
            params['isTyping'],
          ),
        ),
        'updatesStream': _i1.MethodStreamConnector(
          name: 'updatesStream',
          params: {
            'chatId': _i1.ParameterDescription(
              name: 'chatId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
            Map<String, Stream> streamParams,
          ) =>
              (endpoints['chat'] as _i2.ChatEndpoint).updatesStream(
            session,
            chatId: params['chatId'],
          ),
        ),
      },
    );

    modules['dartway_serverpod_core'] = _i4.Endpoints()
      ..initializeEndpoints(server);
  }
}
