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
import '../endpoints/development_endpoint.dart' as _i2;
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    as _i3;
import 'package:serverpod_auth_server/serverpod_auth_server.dart' as _i4;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'development': _i2.DevelopmentEndpoint()
        ..initialize(
          server,
          'development',
          null,
        )
    };
    connectors['development'] = _i1.EndpointConnector(
      name: 'development',
      endpoint: endpoints['development']!,
      methodConnectors: {
        'testNotification': _i1.MethodConnector(
          name: 'testNotification',
          params: {
            'notificationText': _i1.ParameterDescription(
              name: 'notificationText',
              type: _i1.getType<String>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['development'] as _i2.DevelopmentEndpoint)
                  .testNotification(
            session,
            notificationText: params['notificationText'],
          ),
        )
      },
    );
    modules['dartway_serverpod_core'] = _i3.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth'] = _i4.Endpoints()..initializeEndpoints(server);
  }
}
