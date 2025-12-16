import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

class DwModelWrapper implements SerializableModel, ProtocolSerialization {
  static String getClassNameForObject(SerializableModel model) {
    return DwCoreServerpodClient.protocol.getClassNameForObject(model) ??
        'unknown';
  }

  DwModelWrapper.wrap({required this.model})
      : modelId = null,
        this.foreignKeys = {},
        className =
            DwCoreServerpodClient.protocol.getClassNameForObject(model) ??
                'unknown',
        isDeleted = false,
        jsonSerialization = {
          'className':
              DwCoreServerpodClient.protocol.getClassNameForObject(model),
          'data': model.toJson(),
        };

  DwModelWrapper._({
    required this.model,
    required this.modelId,
    required this.foreignKeys,
    required this.isDeleted,
    required this.jsonSerialization,
  }) : className =
            DwCoreServerpodClient.protocol.getClassNameForObject(model) ??
                'unknown';

  final String className;
  final SerializableModel model;
  final Map<String, int> foreignKeys;
  final int? modelId;
  final bool isDeleted;
  final Map<String, dynamic> jsonSerialization;

  // final List<SerializableModel>? entities;

  String get nitMappingClassname => className.split('.').last;

  factory DwModelWrapper.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    final foreignKeys = <String, int>{};

    for (var key in (jsonSerialization['data'] as Map<String, dynamic>).keys) {
      if (key.substring(key.length - 2) == 'Id' &&
          jsonSerialization['data'][key] is int) {
        foreignKeys[key] = jsonSerialization['data'][key] as int;
      }
    }

    return DwModelWrapper._(
      modelId: jsonSerialization['data']['id'],
      foreignKeys: foreignKeys,
      model: DwCoreServerpodClient.protocol.deserializeByClassName(
        jsonSerialization,
      ),
      isDeleted: jsonSerialization['isDeleted'] ?? false,
      jsonSerialization: jsonSerialization,
    );
  }

  @override
  toJson() {
    return {
      'className': DwCoreServerpodClient.protocol.getClassNameForObject(model),
      'data': model.toJson(),
    };
  }

  @override
  toJsonForProtocol() {
    return {
      'className': DwCoreServerpodClient.protocol.getClassNameForObject(model),
      'data': model.toJson(),
    };
  }

  /// Необходим для работы методов copyWith в ChatInitialData и DwAppNotification
  DwModelWrapper copyWith({SerializableModel? model}) {
    return DwModelWrapper.wrap(model: model ?? this.model);
  }
}
