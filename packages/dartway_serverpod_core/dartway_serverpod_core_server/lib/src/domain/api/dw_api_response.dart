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
    this.isRefusal = false,
  });

  /// A rule said no, and this is what it said.
  ///
  /// The one answer a client is meant to show as it arrived: [message] is the
  /// text whoever wrote the rule wrote — "this message was already deleted",
  /// "you have no access to this track" — and it travels to the screen
  /// unedited. Marked with [isRefusal] so the other side can tell it from the
  /// failures that share the `error` field, and act on the difference instead
  /// of matching strings.
  const DwApiResponse.refusal(String message)
    : isOk = false,
      value = null,
      error = message,
      warning = null,
      updatedModels = null,
      isRefusal = true;

  /// The server has no config for this call. **Not a refusal**: no rule
  /// decided anything, the operation simply does not exist on this server, and
  /// a client that meets it has found a hole in the deployment rather than the
  /// answer to a question. It stays an error the app reports.
  const DwApiResponse.notConfigured({required String? source})
    : isOk = false,
      value = null,
      error =
          'Action not configured on server ${source != null ? ' ($source)' : ''}',
      warning = null,
      updatedModels = null,
      isRefusal = false;

  /// The rule that guards this operation said no — `allowSave`, `allowDelete`,
  /// an `accessFilter` that let nothing through. A refusal: the caller is
  /// known, the answer is about them, and nobody needs to be paged for it.
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
  ///
  /// Deliberately **not** marked as a refusal, though it is an answer rather
  /// than an accident. Its text carries a `source` written for whoever reads
  /// the logs, so a client showing it as it arrived would show the user
  /// `Authentication required (getOne for ClubService)`. Sending them to the
  /// login screen instead is the right response, and it needs a channel of its
  /// own rather than this flag.
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
  /// Both travel in the same field, and until this flag existed the client had
  /// no way to tell them apart except by comparing the message to strings it
  /// hoped the server still used. So a refusal reached the app's error policy
  /// looking like an incident, and the alert channel filled up with rules
  /// working exactly as intended.
  ///
  /// Set by [DwApiResponse.refusal] and [DwApiResponse.forbidden]; false for
  /// everything a caller cannot answer — a `DatabaseException`, an exception
  /// caught by the endpoint's guard, a call the server has no config for.
  final bool isRefusal;

  factory DwApiResponse.fromJson(Map<String, dynamic> jsonSerialization) {
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
      isRefusal: jsonSerialization['isRefusal'] as bool? ?? false,
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
      // Written only when true: an older client reads the key it does not know
      // as absent, which is what it already assumed about every error.
      if (isRefusal) 'isRefusal': true,
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
