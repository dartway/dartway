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
      if (key.length > 2 &&
          key.substring(key.length - 2) == 'Id' &&
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
      'isDeleted': isDeleted,
    };
  }

  @override
  toJsonForProtocol() {
    return {
      'className': DwCoreServerpodClient.protocol.getClassNameForObject(model),
      'data': model.toJson(),
      'isDeleted': isDeleted,
    };
  }

  /// Необходим для работы методов copyWith в ChatInitialData и DwAppNotification
  DwModelWrapper copyWith({SerializableModel? model}) {
    final newModel = model ?? this.model;
    return DwModelWrapper._(
      model: newModel,
      modelId: model != null ? newModel.toJson()['id'] : modelId,
      foreignKeys: model != null ? _extractForeignKeys(newModel) : foreignKeys,
      isDeleted: isDeleted,
      jsonSerialization: model != null
          ? {
              'className':
                  DwCoreServerpodClient.protocol.getClassNameForObject(newModel),
              'data': newModel.toJson(),
            }
          : jsonSerialization,
    );
  }

  static Map<String, int> _extractForeignKeys(SerializableModel model) {
    final foreignKeys = <String, int>{};
    final json = model.toJson();
    if (json is Map<String, dynamic>) {
      for (var key in json.keys) {
        if (key.length > 2 &&
            key.substring(key.length - 2) == 'Id' &&
            json[key] is int) {
          foreignKeys[key] = json[key] as int;
        }
      }
    }
    return foreignKeys;
  }
}
