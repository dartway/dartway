import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical digest binding repository models to a signed offline manifest.
abstract final class DwOfflineRepositoryContentRevision {
  static String compute(Iterable<Map<String, Object?>> encodedModels) {
    final models =
        encodedModels.map(_EncodedRepositoryModel.new).toList(growable: false)
          ..sort(_EncodedRepositoryModel.compare);
    final canonicalJson = jsonEncode(<String, Object?>{
      'models': models
          .map((model) => _canonicalizeJson(model.encoded))
          .toList(growable: false),
    });
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  /// Reconstructs the unique model set stored across repository responses.
  ///
  /// Only the top-level `value` of each response participates. This avoids
  /// treating nested relations inside a model as independently cached models.
  static String computeFromRepositoryResponses(
    Iterable<Map<String, Object?>> responses,
  ) {
    final uniqueModels = <String, Map<String, Object?>>{};

    for (final response in responses) {
      final value = response['value'];
      if (value == null) continue;

      final candidates = switch (value) {
        Map<String, Object?> model => <Map<String, Object?>>[model],
        List<Object?> models => models.map((model) {
          if (model is! Map<String, Object?>) {
            throw const FormatException(
              'Repository response contains a non-model value.',
            );
          }
          return model;
        }),
        _ => throw const FormatException(
          'Repository response has an unsupported value.',
        ),
      };

      for (final candidate in candidates) {
        final model = _EncodedRepositoryModel(candidate);
        if (model.modelId == null || candidate['isDeleted'] is! bool) {
          throw const FormatException(
            'Repository model identity is incomplete.',
          );
        }
        final identity = '${model.className}:${model.modelId}';
        final previous = uniqueModels[identity];
        if (previous == null) {
          uniqueModels[identity] = candidate;
          continue;
        }
        if (jsonEncode(_canonicalizeJson(previous)) !=
            jsonEncode(_canonicalizeJson(candidate))) {
          throw FormatException(
            'Repository responses contain conflicting model $identity.',
          );
        }
      }
    }

    return compute(uniqueModels.values);
  }

  static Object? _canonicalizeJson(Object? value) {
    if (value == null || value is bool || value is String) return value;
    if (value is num) {
      if (value is double && !value.isFinite) {
        throw ArgumentError.value(value, 'encodedModels');
      }
      return value;
    }
    if (value is List<Object?>) {
      return value.map(_canonicalizeJson).toList(growable: false);
    }
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList(growable: false)..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalizeJson(value[key]),
      };
    }
    throw ArgumentError.value(value, 'encodedModels');
  }
}

final class _EncodedRepositoryModel {
  _EncodedRepositoryModel(this.encoded)
    : className = _readClassName(encoded),
      modelId = _readModelId(encoded);

  final Map<String, Object?> encoded;
  final String className;
  final int? modelId;

  static int compare(
    _EncodedRepositoryModel left,
    _EncodedRepositoryModel right,
  ) {
    final byClassName = left.className.compareTo(right.className);
    if (byClassName != 0) return byClassName;
    return (left.modelId ?? 0).compareTo(right.modelId ?? 0);
  }

  static String _readClassName(Map<String, Object?> encoded) {
    final className = encoded['className'];
    if (className is! String || className.isEmpty) {
      throw ArgumentError.value(encoded, 'encodedModels');
    }
    return className;
  }

  static int? _readModelId(Map<String, Object?> encoded) {
    final data = encoded['data'];
    if (data is! Map<String, Object?>) {
      throw ArgumentError.value(encoded, 'encodedModels');
    }
    final modelId = data['id'];
    if (modelId != null && modelId is! int) {
      throw ArgumentError.value(encoded, 'encodedModels');
    }
    return modelId as int?;
  }
}
