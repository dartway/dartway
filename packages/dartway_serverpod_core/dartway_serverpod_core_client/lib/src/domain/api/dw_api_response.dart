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
    this.isRefusal = false,
  });

  /// A rule on the server said no, and [message] is what it said.
  ///
  /// The twin of `DwApiResponse.refusal` on the server side; here it is what a
  /// locally built response uses to refuse the same way the server would.
  const DwApiResponse.refusal(String message)
    : isOk = false,
      value = null,
      error = message,
      warning = null,
      updatedModels = null,
      isRefusal = true;

  const DwApiResponse.notConfigured()
    : isOk = false,
      value = null,
      error = 'This action is not supported by the server',
      warning = null,
      updatedModels = null,
      isRefusal = false;

  const DwApiResponse.forbidden()
    : isOk = false,
      value = null,
      error = 'Not enough permissions',
      warning = null,
      updatedModels = null,
      isRefusal = true;

  /// The caller is not signed in and the config did not opt into anonymous
  /// access. Distinct from [DwApiResponse.forbidden]: there the caller is
  /// known and lacks permission, here there is no caller at all — the client
  /// can act on that by sending the user to the login screen.
  const DwApiResponse.notAuthenticated({String? source})
    : isOk = false,
      value = null,
      error = 'Authentication required${source != null ? ' ($source)' : ''}',
      warning = null,
      updatedModels = null,
      isRefusal = false;

  final bool isOk;
  final T? value;
  final String? warning;
  final String? error;
  final List<DwModelWrapper>? updatedModels;

  /// Whether [error] is a rule saying no rather than something breaking.
  ///
  /// The two share the `error` field, and only the server knows which it
  /// built. `DwRepository.processApiResponse` reads this flag to answer with a
  /// `DwRefusal` — a message meant for the user — instead of an exception the
  /// app's error policy would report as an incident.
  ///
  /// **False when the key is absent**, which is how a server older than the
  /// flag reads: every error stays an incident, exactly as before.
  final bool isRefusal;

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
      isRefusal: jsonSerialization['isRefusal'] as bool? ?? false,
    );
  }

  @override
  toJson() {
    return {
      'isOk': isOk,
      'value': _serializeValue(value),
      if (warning != null) 'warning': warning,
      if (error != null) 'error': error,
      if (isRefusal) 'isRefusal': true,
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
