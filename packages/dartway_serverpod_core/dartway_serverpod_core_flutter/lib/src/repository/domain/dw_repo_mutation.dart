import 'dw_repo_binding.dart';

/// The persisted shape version of the write mutation envelope.
enum DwRepoMutationOperation { save, delete }

/// One immutable offline repository mutation ready for durable enqueue.
class DwRepoMutation {
  DwRepoMutation._({
    required this.schemaVersion,
    required this.mutationId,
    required this.idempotencyKey,
    required this.scope,
    required this.className,
    required this.entityType,
    required this.apiGroup,
    required this.operation,
    required this.entityId,
    required Map<String, dynamic> protocolPayload,
    required Map<String, dynamic>? opaqueMetadata,
    required DateTime createdAtUtc,
  }) : protocolPayload = _freezeJsonMap(protocolPayload),
       opaqueMetadata = opaqueMetadata == null
           ? null
           : _freezeJsonMap(opaqueMetadata),
       createdAtUtc = createdAtUtc.toUtc() {
    _validate();
  }

  factory DwRepoMutation.save({
    required DwRepoScope scope,
    required String className,
    required String entityType,
    required String mutationId,
    required Map<String, dynamic> protocolPayload,
    String? apiGroup,
    int? entityId,
    Map<String, dynamic>? opaqueMetadata,
    DateTime? createdAtUtc,
  }) => DwRepoMutation._(
    schemaVersion: currentSchemaVersion,
    mutationId: mutationId,
    idempotencyKey: mutationId,
    scope: scope,
    className: className,
    entityType: entityType,
    apiGroup: apiGroup,
    operation: DwRepoMutationOperation.save,
    entityId: entityId,
    protocolPayload: protocolPayload,
    opaqueMetadata: opaqueMetadata,
    createdAtUtc: createdAtUtc ?? DateTime.now().toUtc(),
  );

  factory DwRepoMutation.delete({
    required DwRepoScope scope,
    required String className,
    required String entityType,
    required int entityId,
    required String mutationId,
    required Map<String, dynamic> protocolPayload,
    String? apiGroup,
    Map<String, dynamic>? opaqueMetadata,
    DateTime? createdAtUtc,
  }) => DwRepoMutation._(
    schemaVersion: currentSchemaVersion,
    mutationId: mutationId,
    idempotencyKey: mutationId,
    scope: scope,
    className: className,
    entityType: entityType,
    apiGroup: apiGroup,
    operation: DwRepoMutationOperation.delete,
    entityId: entityId,
    protocolPayload: protocolPayload,
    opaqueMetadata: opaqueMetadata,
    createdAtUtc: createdAtUtc ?? DateTime.now().toUtc(),
  );

  factory DwRepoMutation.fromJson(Map<String, dynamic> json) {
    return DwRepoMutation._(
      schemaVersion: json['schemaVersion'] as int,
      mutationId: json['mutationId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      scope: DwRepoScope(json['scopeStorageKey'] as String),
      className: json['className'] as String,
      entityType: json['entityType'] as String,
      apiGroup: json['apiGroup'] as String?,
      operation: _operationFromJson(json['operation'] as String),
      entityId: json['entityId'] as int?,
      protocolPayload: Map<String, dynamic>.from(
        json['protocolPayload'] as Map,
      ),
      opaqueMetadata: json['opaqueMetadata'] == null
          ? null
          : Map<String, dynamic>.from(json['opaqueMetadata'] as Map),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
    );
  }

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String mutationId;
  final String idempotencyKey;
  final DwRepoScope scope;
  final String className;
  final String entityType;
  final String? apiGroup;
  final DwRepoMutationOperation operation;
  final int? entityId;
  final Map<String, dynamic> protocolPayload;
  final Map<String, dynamic>? opaqueMetadata;
  final DateTime createdAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'mutationId': mutationId,
    'idempotencyKey': idempotencyKey,
    'scopeStorageKey': scope.storageKey,
    'className': className,
    'entityType': entityType,
    'apiGroup': apiGroup,
    'operation': operation.name,
    'entityId': entityId,
    'protocolPayload': protocolPayload,
    'opaqueMetadata': opaqueMetadata,
    'createdAtUtc': createdAtUtc.toIso8601String(),
  };

  static DwRepoMutationOperation _operationFromJson(String value) {
    return DwRepoMutationOperation.values.firstWhere(
      (operation) => operation.name == value,
      orElse: () => throw StateError('Unsupported repository mutation $value.'),
    );
  }

  void _validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw StateError(
        'Unsupported repository mutation schema $schemaVersion.',
      );
    }
    if (mutationId.trim().isEmpty ||
        mutationId != mutationId.trim() ||
        idempotencyKey.trim().isEmpty ||
        idempotencyKey != idempotencyKey.trim()) {
      throw StateError('Repository mutation ids must not be blank.');
    }
    if (className.trim().isEmpty ||
        className != className.trim() ||
        entityType.trim().isEmpty ||
        entityType != entityType.trim()) {
      throw StateError('Repository mutation type names must not be blank.');
    }
    if (apiGroup != null &&
        (apiGroup!.trim().isEmpty || apiGroup != apiGroup!.trim())) {
      throw StateError('Repository mutation apiGroup must be trimmed or null.');
    }
    if (operation == DwRepoMutationOperation.delete) {
      if (entityId == null || entityId == 0) {
        throw StateError(
          'Repository delete mutations must include a non-zero entity id.',
        );
      }
    } else if (entityId == 0) {
      throw StateError(
        'Repository save mutation ids must be non-zero when present.',
      );
    }
  }

  static Map<String, dynamic> _freezeJsonMap(Map<String, dynamic> source) {
    final frozenEntries = <String, dynamic>{};
    for (final entry in source.entries) {
      frozenEntries[entry.key] = _freezeJsonValue(entry.value);
    }
    return Map<String, dynamic>.unmodifiable(frozenEntries);
  }

  static Object? _freezeJsonValue(Object? value) {
    if (value == null || value is bool || value is String || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(
          value,
          'value',
          'Repository mutation numbers must be finite.',
        );
      }
      return value;
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map<Object?>(_freezeJsonValue));
    }
    if (value is Map) {
      final frozenEntries = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError.value(
            value,
            'value',
            'Repository mutation maps must have string keys.',
          );
        }
        frozenEntries[entry.key as String] = _freezeJsonValue(entry.value);
      }
      return Map<String, dynamic>.unmodifiable(frozenEntries);
    }
    throw ArgumentError.value(
      value,
      'value',
      'Repository mutations must stay JSON-compatible.',
    );
  }
}
