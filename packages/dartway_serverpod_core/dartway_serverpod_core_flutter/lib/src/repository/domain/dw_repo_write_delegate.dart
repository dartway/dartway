import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_repo_binding.dart';
import 'dw_repo_mutation.dart';

typedef DwRepoWriteScope = DwRepoScope;
typedef DwRepoWriteBinding = DwRepoBinding;

/// The result of an atomic conditional mutation enqueue.
enum DwRepoMutationEnqueueResult { accepted, stale }

/// One pre-dispatch offline write plan for a canonical repository mutation.
///
/// Returning `null` from `prepareSaveMutation` / `prepareDeleteMutation` means
/// that this operation/data combination is not opted into durable offline
/// writes.
class DwRepoWritePlan<Value> {
  const DwRepoWritePlan({
    required this.optimisticResponse,
    required this.onlineTransport,
    this.opaqueMetadata,
  });

  /// Canonical optimistic repository response returned after durable enqueue.
  ///
  /// It must be a successful `DwApiResponse` for the same public API shape as
  /// the online boundary. `updatedModels`, when present, must be listener-safe.
  final DwApiResponse<Value> optimisticResponse;

  /// The app-supplied idempotent online transport used for the first attempt.
  ///
  /// Core passes the already-built canonical mutation so the first online
  /// request and a later queued replay share the same idempotency key.
  final Future<DwApiResponse<Value>> Function(DwRepoMutation mutation)
  onlineTransport;

  /// Application-owned metadata persisted with the mutation envelope.
  final Map<String, dynamic>? opaqueMetadata;
}

/// The optional persistence boundary for canonical `dw.repo` writes.
///
/// Implementations resolve an opaque authenticated [DwRepoWriteBinding],
/// decide per operation/model whether offline writes are enabled, and enqueue
/// mutations atomically only while the exact binding is still current.
abstract interface class DwRepoWriteDelegate {
  const DwRepoWriteDelegate();

  /// Resolves the current runtime capability, or `null` when writes are not
  /// eligible for persistence (for example while signed out).
  Future<DwRepoWriteBinding?> resolveBinding();

  /// Reports whether [binding] is still the exact current runtime capability.
  /// Implementations must return `false` for an inactive [binding].
  Future<bool> isBindingCurrent(DwRepoWriteBinding binding);

  /// Returns a canonical offline save plan, or `null` when this save should not
  /// fall back to a durable offline mutation.
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  });

  /// Returns a canonical offline delete plan, or `null` when this delete
  /// should not fall back to a durable offline mutation.
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  });

  /// Atomically writes only while [binding] is current at the commit point.
  ///
  /// Persistent delegates must implement this condition transactionally with
  /// the row write; a pre-write read of [isBindingCurrent] is insufficient.
  /// Return [DwRepoMutationEnqueueResult.stale] without committing if the
  /// capability changed.
  Future<DwRepoMutationEnqueueResult> enqueueMutationIfCurrent({
    required DwRepoWriteBinding binding,
    required DwRepoMutation mutation,
  });
}
