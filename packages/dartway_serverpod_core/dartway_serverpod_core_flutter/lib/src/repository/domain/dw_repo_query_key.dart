import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable identity for a repository read that can be used by offline storage.
///
/// Query values may contain only JSON-compatible scalars, lists, and maps with
/// string keys. Map key order is normalised while list order remains part of
/// the identity.
class DwRepoQueryKey<Model> {
  DwRepoQueryKey._canonical({
    required this.operation,
    required this.modelClassName,
    required this.apiGroup,
    required this.canonicalFilters,
    required this.canonicalOrdering,
    required this.canonicalPagination,
    required this.canonicalIncludes,
  }) : _canonicalJson = _buildCanonicalJson(
         operation: operation,
         modelClassName: modelClassName,
         apiGroup: apiGroup,
         filters: canonicalFilters,
         ordering: canonicalOrdering,
         pagination: canonicalPagination,
         includes: canonicalIncludes,
       );

  /// Creates a key for a single-model read.
  factory DwRepoQueryKey.getOne({
    required String modelClassName,
    String? apiGroup,
    Object? filters,
    Object? ordering,
    Object? pagination,
    Object? includes,
  }) => DwRepoQueryKey<Model>._canonical(
    operation: 'getOne',
    modelClassName: modelClassName,
    apiGroup: apiGroup,
    canonicalFilters: _canonicalize(filters),
    canonicalOrdering: _canonicalize(ordering),
    canonicalPagination: _canonicalize(pagination),
    canonicalIncludes: _canonicalize(includes),
  );

  /// Creates a key for a list read.
  factory DwRepoQueryKey.getAll({
    required String modelClassName,
    String? apiGroup,
    Object? filters,
    Object? ordering,
    Object? pagination,
    Object? includes,
  }) => DwRepoQueryKey<Model>._canonical(
    operation: 'getAll',
    modelClassName: modelClassName,
    apiGroup: apiGroup,
    canonicalFilters: _canonicalize(filters),
    canonicalOrdering: _canonicalize(ordering),
    canonicalPagination: _canonicalize(pagination),
    canonicalIncludes: _canonicalize(includes),
  );

  final String operation;
  final String modelClassName;
  final String? apiGroup;
  final Object? canonicalFilters;
  final Object? canonicalOrdering;
  final Object? canonicalPagination;
  final Object? canonicalIncludes;
  final String _canonicalJson;

  /// SHA-256 of the canonical UTF-8 JSON representation.
  String toStorageKey() =>
      sha256.convert(utf8.encode(_canonicalJson)).toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DwRepoQueryKey<Model> && _canonicalJson == other._canonicalJson;

  @override
  int get hashCode => _canonicalJson.hashCode;

  @override
  String toString() =>
      'DwRepoQueryKey<$Model>('
      'operation: $operation, '
      'modelClassName: $modelClassName, '
      'apiGroup: ${apiGroup == null ? 'absent' : 'present'}, '
      'filters: ${_describeShape(canonicalFilters)}, '
      'ordering: ${_describeShape(canonicalOrdering)}, '
      'pagination: ${_describeShape(canonicalPagination)}, '
      'includes: ${_describeShape(canonicalIncludes)}, '
      'storageKey: ${toStorageKey()}'
      ')';

  static String _buildCanonicalJson({
    required String operation,
    required String modelClassName,
    required String? apiGroup,
    required Object? filters,
    required Object? ordering,
    required Object? pagination,
    required Object? includes,
  }) => jsonEncode(<String, Object?>{
    'apiGroup': apiGroup,
    'filters': filters,
    'includes': includes,
    'modelClassName': modelClassName,
    'operation': operation,
    'ordering': ordering,
    'pagination': pagination,
  });

  static Object? _canonicalize(Object? queryValue) {
    if (queryValue == null ||
        queryValue is bool ||
        queryValue is String ||
        queryValue is int) {
      return queryValue;
    }
    if (queryValue is double) {
      if (!queryValue.isFinite) {
        throw ArgumentError.value(
          queryValue,
          'queryValue',
          'Unsupported query key value: non-finite numbers are not valid JSON.',
        );
      }
      return queryValue;
    }
    if (queryValue is List) {
      return List<Object?>.unmodifiable(queryValue.map<Object?>(_canonicalize));
    }
    if (queryValue is Map) {
      final canonicalMap = <String, Object?>{};
      final keys = <String>[];
      for (final entry in queryValue.entries) {
        if (entry.key is! String) {
          throw ArgumentError.value(
            queryValue,
            'queryValue',
            'Unsupported query key value: map keys must be strings.',
          );
        }
        keys.add(entry.key as String);
      }
      keys.sort();
      for (final key in keys) {
        canonicalMap[key] = _canonicalize(queryValue[key]);
      }
      return Map<String, Object?>.unmodifiable(canonicalMap);
    }
    throw ArgumentError.value(
      queryValue,
      'queryValue',
      'Unsupported query key value of type ${queryValue.runtimeType}. '
          'Only null, bool, numbers, strings, lists, and maps are supported.',
    );
  }

  static String _describeShape(Object? queryValue) {
    if (queryValue == null) return 'null';
    if (queryValue is List) return 'list(${queryValue.length})';
    if (queryValue is Map) return 'map(${queryValue.length})';
    return queryValue.runtimeType.toString();
  }
}
