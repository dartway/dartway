import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

// Code to be pasted into Protocol after serverpod generate
// if (data is Map<String, dynamic>) {
//   final manualDeserialization =
//       _i10.DwApiResponse.manualDeserialization<T>(data);
//   if (manualDeserialization != null) return manualDeserialization;
// }
class DwApiResponse<T> implements SerializableModel {
  const DwApiResponse({
    required this.isOk,
    required this.value,
    this.warning,
    this.error,
    this.updatedModels,
  });

  const DwApiResponse.notConfigured()
    : isOk = false,
      value = null,
      error = 'Действие не поддерживается сервером',
      warning = null,
      updatedModels = null;

  const DwApiResponse.forbidden()
    : isOk = false,
      value = null,
      error = 'Недостаточно полномочий',
      warning = null,
      updatedModels = null;

  final bool isOk;
  final T? value;
  final String? warning;
  final String? error;
  final List<DwModelWrapper>? updatedModels;

  static K? manualDeserialization<K>(Map<String, dynamic> jsonSerialization) {
    if (K == DwApiResponse<List<int>>) {
      return DwApiResponse<List<int>>.fromJson(jsonSerialization) as K;
    } else if (K == DwApiResponse<int>) {
      return DwApiResponse<int>.fromJson(jsonSerialization) as K;
    } else if (K == DwApiResponse<String>) {
      return DwApiResponse<String>.fromJson(jsonSerialization) as K;
    } else if (K == DwApiResponse<bool>) {
      return DwApiResponse<bool>.fromJson(jsonSerialization) as K;
    } else if (K == DwApiResponse<DwModelWrapper>) {
      return DwApiResponse<DwModelWrapper>.fromJson(jsonSerialization) as K;
    } else if (K == DwApiResponse<List<DwModelWrapper>>) {
      return DwApiResponse<List<DwModelWrapper>>.fromJson(jsonSerialization)
          as K;
    }

    return null;

    // if (T.toString().startsWith('ApiResponse')) {
    // print('Exact option for $K deserialization not configured');
    // throw UnimplementedError();
    // }
  }
  // print(T.toString());

  factory DwApiResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
    // Type t;
  ) {
    // final t = jsonSerialization['value'];
    // try {
    return DwApiResponse(
      isOk: jsonSerialization['isOk'] as bool,
      value:
          jsonSerialization['value'] == null
              ? null
              : DwCoreServerpodClient.protocol.deserialize<T>(
                jsonSerialization['value'],
              ),
      warning: jsonSerialization['warning'] as String?,
      error: jsonSerialization['error'] as String?,
      updatedModels:
          jsonSerialization['updatedModels'] == null
              ? null
              : (jsonSerialization['updatedModels'] as List)
                      .map(
                        (e) => DwCoreServerpodClient.protocol
                            .deserialize<DwModelWrapper>(e),
                      )
                      .toList()
                  as dynamic,
    );
  }

  @override
  toJson() {
    return {
      'isOk': isOk,
      'value':
          value is SerializableModel
              ? (value as SerializableModel).toJson()
              : value,
      if (warning != null) 'warning': warning,
      if (error != null) 'error': error,
      if (updatedModels != null)
        'updatedModels': updatedModels?.toJson(valueToJson: (v) => v.toJson()),
    };
  }
}
