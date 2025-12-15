import 'package:serverpod/serverpod.dart';

import 'dw_model_wrapper.dart';

class DwApiResponse<T> implements SerializableModel {
  static SerializationManagerServer get _protocol =>
      Serverpod.instance.serializationManager;

  const DwApiResponse({
    required this.isOk,
    required this.value,
    this.warning,
    this.error,
    this.updatedModels,
  });

  const DwApiResponse.notConfigured({
    required String? source,
  })  : isOk = false,
        value = null,
        error =
            'Action not configured on server ${source != null ? ' ($source)' : ''}',
        warning = null,
        updatedModels = null;

  const DwApiResponse.forbidden()
      : isOk = false,
        value = null,
        error = 'Not enough permissions',
        warning = null,
        updatedModels = null;

  final bool isOk;
  final T? value;
  final String? warning;
  final String? error;
  final List<DwModelWrapper>? updatedModels;

  factory DwApiResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DwApiResponse(
      isOk: jsonSerialization['isOk'] as bool,
      value: _protocol.deserialize<T>(jsonSerialization['value']),
      warning: jsonSerialization['warning'] as String?,
      error: jsonSerialization['error'] as String?,
      updatedModels: jsonSerialization['updatedModels'] == null
          ? null
          : (jsonSerialization['updatedModels'] as List)
              .map((e) => _protocol.deserialize<DwModelWrapper>(e))
              .toList() as dynamic,
    );
  }

  @override
  toJson() {
    return {
      'isOk': isOk,
      'value': value is SerializableModel
          ? (value as SerializableModel).toJson()
          : value,
      if (warning != null) 'warning': warning,
      if (error != null) 'error': error,
      if (updatedModels != null)
        'updatedModels': updatedModels?.toJson(valueToJson: (v) => v.toJson()),
    };
  }
}
