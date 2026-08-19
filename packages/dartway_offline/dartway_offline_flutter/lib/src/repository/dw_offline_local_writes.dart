import 'dart:convert';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

import '../storage/dw_offline_database.dart';

final class DwOfflineMutationTarget {
  DwOfflineMutationTarget({required this.entityType, required this.entityId}) {
    if (entityType.trim().isEmpty ||
        entityType != entityType.trim() ||
        entityId.trim().isEmpty ||
        entityId != entityId.trim()) {
      throw ArgumentError('Offline mutation target must be trimmed.');
    }
  }

  final String entityType;
  final String entityId;
}

abstract interface class DwOfflineMutationPlanner {
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  });

  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  });

  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation);
}

/// Bridges opted-in repository writes to the durable offline outbox.
final class DwOfflineLocalWrites implements DwRepoLocalWrites {
  DwOfflineLocalWrites({
    required DwOfflineDatabase database,
    required DwOfflineMutationPlanner mutationPlanner,
  }) : _database = database,
       _mutationPlanner = mutationPlanner;

  final DwOfflineDatabase _database;
  final DwOfflineMutationPlanner _mutationPlanner;
  Future<void> _operationTail = Future<void>.value();
  DwRepoBinding? _currentBinding;

  Future<void> activateUserScope(String userScopeId) {
    return _serialize(() async {
      final scope = DwRepoScope(userScopeId);
      if (_currentBinding?.scope == scope) return;
      _currentBinding?.invalidate();
      _currentBinding = DwRepoBinding(scope: scope);
    });
  }

  Future<void> deactivateUserScope() {
    return _serialize(() async {
      _currentBinding?.invalidate();
      _currentBinding = null;
    });
  }

  @override
  Future<DwRepoBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async {
    return binding.isActive && identical(binding, _currentBinding);
  }

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async {
    if (!await isBindingCurrent(binding)) return null;
    return _mutationPlanner.prepareSaveMutation(
      binding: binding,
      model: model,
      apiGroup: apiGroup,
    );
  }

  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async {
    if (!await isBindingCurrent(binding)) return null;
    return _mutationPlanner.prepareDeleteMutation(
      binding: binding,
      model: model,
      apiGroup: apiGroup,
    );
  }

  @override
  Future<R> write<R>(Future<R> Function(DwRepoLocalWriteTx tx) body) {
    // Two layers, and both are needed. `_serialize` orders this against
    // `activateUserScope` / `deactivateUserScope`, so a sign-out cannot land
    // between the binding check and the row write; the drift transaction makes
    // the row write itself atomic with whatever else the body did.
    return _serialize(
      () => _database.transaction(() => body(_DwOfflineWriteTx(this))),
    );
  }

  Future<void> _enqueue(DwRepoMutation mutation) async {
    final binding = _currentBinding;
    if (binding == null) {
      throw StateError('Offline outbox has no active user scope.');
    }
    if (mutation.scope != binding.scope) {
      throw StateError('Offline mutation scope does not match.');
    }
    final target = _mutationPlanner.targetFor(mutation);
    if (target == null) {
      throw StateError('Repository mutation is not allowed offline.');
    }
    final createdAtEpochMs = mutation.createdAtUtc.millisecondsSinceEpoch;
    await _database.coalesceOutboxIntent(
      DwOfflineOutboxCompanion.insert(
        userScopeId: binding.scope.storageKey,
        mutationId: mutation.mutationId,
        entityType: target.entityType,
        entityId: target.entityId,
        mutationType: mutation.operation.name,
        idempotencyKey: mutation.idempotencyKey,
        envelopeJson: jsonEncode(mutation.toJson()),
        createdAtEpochMs: createdAtEpochMs,
        updatedAtEpochMs: createdAtEpochMs,
      ),
    );
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}

final class _DwOfflineWriteTx implements DwRepoLocalWriteTx {
  const _DwOfflineWriteTx(this._store);

  final DwOfflineLocalWrites _store;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      binding.isActive && identical(binding, _store._currentBinding);

  @override
  Future<void> enqueue(DwRepoMutation mutation) => _store._enqueue(mutation);
}
