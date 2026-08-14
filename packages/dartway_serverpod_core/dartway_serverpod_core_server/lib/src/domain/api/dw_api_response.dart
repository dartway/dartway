import 'package:serverpod/serverpod.dart';

import 'dw_model_wrapper.dart';
import 'dw_protocol_json.dart';

/// The envelope every CRUD call answers with.
///
/// Implements [ProtocolSerialization] deliberately, and it is the link that
/// makes the rest of the chain reachable. This envelope flattens its own
/// contents — the value and the updated models are turned into maps here, by
/// hand — so by the time Serverpod's encoder walks the result there are no
/// model objects left in it to recognise. Whatever choice is made *here* is the
/// final one for everything nested; a `toJson` on this level publishes the
/// `serverOnly` columns of every model inside, no matter how carefully the
/// wrappers below it serialise themselves.
class DwApiResponse<T> implements SerializableModel, ProtocolSerialization {
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

  /// The caller is not signed in and the config did not opt into anonymous
  /// access. Distinct from [DwApiResponse.forbidden]: there the caller is
  /// known and lacks permission, here there is no caller at all — the client
  /// can act on that by sending the user to the login screen.
  const DwApiResponse.notAuthenticated({String? source})
      : isOk = false,
        value = null,
        error =
            'Authentication required${source != null ? ' ($source)' : ''}',
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
              .toList(),
    );
  }

  /// Everything the envelope carries, `serverOnly` fields included. For
  /// server-side use; [toJsonForProtocol] is what reaches a client.
  @override
  toJson() => _json(forProtocol: false);

  @override
  Map<String, dynamic> toJsonForProtocol() => _json(forProtocol: true);

  Map<String, dynamic> _json({required bool forProtocol}) {
    return {
      'isOk': isOk,
      'value': _serializeValue(value, forProtocol: forProtocol),
      if (warning != null) 'warning': warning,
      if (error != null) 'error': error,
      if (updatedModels != null)
        'updatedModels': [
          for (final model in updatedModels!)
            forProtocol ? model.toJsonForProtocol() : model.toJson(),
        ],
    };
  }

  static dynamic _serializeValue(dynamic value, {required bool forProtocol}) {
    if (value is SerializableModel) {
      return forProtocol ? dwJsonForProtocol(value) : value.toJson();
    } else if (value is List) {
      return value
          .map((e) => _serializeValue(e, forProtocol: forProtocol))
          .toList();
    }
    return value;
  }
}
