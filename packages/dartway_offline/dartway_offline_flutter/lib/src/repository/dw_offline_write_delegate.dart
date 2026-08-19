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
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  });

  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  });

  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation);
}

/// Bridges opted-in repository writes to the durable offline outbox.
final class DwOfflineWriteDelegate implements DwRepoWriteDelegate {
  DwOfflineWriteDelegate({
    required DwOfflineDatabase database,
    required DwOfflineMutationPlanner mutationPlanner,
  }) : _database = database,
       _mutationPlanner = mutationPlanner;

  final DwOfflineDatabase _database;
  final DwOfflineMutationPlanner _mutationPlanner;
  Future<void> _operationTail = Future<void>.value();
  DwRepoWriteBinding? _currentBinding;

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
  Future<DwRepoWriteBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoWriteBinding binding) async {
    return binding.isActive && identical(binding, _currentBinding);
  }

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
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
    required DwRepoWriteBinding binding,
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
  Future<DwRepoMutationEnqueueResult> enqueueMutationIfCurrent({
    required DwRepoWriteBinding binding,
    required DwRepoMutation mutation,
  }) {
    return _serialize(() async {
      if (!binding.isActive || !identical(binding, _currentBinding)) {
        return DwRepoMutationEnqueueResult.stale;
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
      return DwRepoMutationEnqueueResult.accepted;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}
