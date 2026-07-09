import 'package:serverpod_client/serverpod_client.dart'
    show SerializationManager;

export 'package:serverpod_client/serverpod_client.dart';

export 'src/domain/api/dw_api_response.dart';
export 'src/domain/api/dw_auth_data.dart';
export 'src/domain/api/dw_backend_filter.dart';
export 'src/domain/api/dw_model_wrapper.dart';
export 'src/domain/api/dw_order_by.dart';
export 'src/protocol/protocol.dart';

class DwCoreServerpodClient {
  static late final SerializationManager protocol;
}
