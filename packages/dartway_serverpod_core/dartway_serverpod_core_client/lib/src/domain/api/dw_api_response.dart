import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

// `serverpod generate` overwrites the generated protocol and drops this hook —
// re-paste it into `Protocol.deserialize<T>` (protocol.dart), right after
// `t ??= T;`:
//
//   if (data is Map<String, dynamic>) {
//     final manualDeserialization =
//         _iNN.DwApiResponse.manualDeserialization<T>(data);
//     if (manualDeserialization != null) {
//       return manualDeserialization;
//     }
//   }
//
// `_iNN` is whatever alias the regenerated file gives this library — the number
// moves between generations, so read it off the imports instead of copying one.
//
// Why it is needed at all: `extraClasses` does not understand generics. The
// generator emits a check against the *raw* type (`t == DwApiResponse`, i.e.
// `DwApiResponse<dynamic>`), while the wire carries `DwApiResponse<DwModelWrapper>`,
// `DwApiResponse<List<DwModelWrapper>>`, `<int>`, `<bool>`… As `Type` objects
// those never equal the raw one, so the generated branch is dead and every CRUD
// response fails to deserialize. [manualDeserialization] resolves the concrete
// instantiations by hand.
//
// The code still compiles without the hook — it breaks at runtime. Verify after
// every generate:
//   grep -n 'manualDeserialization' lib/src/protocol/protocol.dart
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
    } else if (K == DwApiResponse<DwModelWrapper?>) {
      return DwApiResponse<DwModelWrapper?>.fromJson(jsonSerialization) as K;
    }

    return null;
  }

  factory DwApiResponse.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwApiResponse(
      isOk: jsonSerialization['isOk'] as bool,
      value: jsonSerialization['value'] == null
          ? null
          : DwCoreServerpodClient.protocol.deserialize<T>(
              jsonSerialization['value'],
            ),
      warning: jsonSerialization['warning'] as String?,
      error: jsonSerialization['error'] as String?,
      updatedModels: jsonSerialization['updatedModels'] == null
          ? null
          : (jsonSerialization['updatedModels'] as List)
                .map(
                  (e) => DwCoreServerpodClient.protocol
                      .deserialize<DwModelWrapper>(e),
                )
                .toList(),
    );
  }

  @override
  toJson() {
    return {
      'isOk': isOk,
      'value': _serializeValue(value),
      if (warning != null) 'warning': warning,
      if (error != null) 'error': error,
      if (updatedModels != null)
        'updatedModels': updatedModels?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  static dynamic _serializeValue(dynamic value) {
    if (value is SerializableModel) {
      return value.toJson();
    } else if (value is List) {
      return value.map((e) => _serializeValue(e)).toList();
    }
    return value;
  }
}
