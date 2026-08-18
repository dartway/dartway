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
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as _i1;
import 'package:dartway_push_client/dartway_push_client.dart' as _i2;
import 'package:serverpod_client/serverpod_client.dart' as _i3;
import 'protocol.dart' as _i4;

class Modules {
  Modules(Client client) {
    dartway_serverpod_core = _i1.Caller(client);
    dartway_push = _i2.Caller(client);
  }

  late final _i1.Caller dartway_serverpod_core;

  late final _i2.Caller dartway_push;
}

class Client extends _i3.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_i3.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_i3.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i4.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    modules = Modules(this);
  }

  late final Modules modules;

  @override
  Map<String, _i3.EndpointRef> get endpointRefLookup => {};

  @override
  Map<String, _i3.ModuleEndpointCaller> get moduleLookup => {
    'dartway_serverpod_core': modules.dartway_serverpod_core,
    'dartway_push': modules.dartway_push,
  };
}
