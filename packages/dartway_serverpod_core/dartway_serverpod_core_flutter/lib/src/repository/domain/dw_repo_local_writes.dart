import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_repo_binding.dart';
import 'dw_repo_mutation.dart';

/// The outcome of one conditional enqueue.
enum DwRepoEnqueue {
  /// The mutation is durably queued under a binding that was still current.
  accepted,

  /// The binding stopped being current, so nothing was queued.
  stale,
}

/// One pre-dispatch local write plan for a canonical repository mutation.
///
/// A store answers two questions with it, and only two: does this write get
/// kept, and what does the caller see while it waits. It does not answer how
/// the write reaches the server — the core sends it, by the one path it always
/// sends writes by, and hands the store the same [DwRepoMutation] it sent so a
/// later replay carries the identity of the first attempt.
///
/// Returning `null` from `prepareSaveMutation` / `prepareDeleteMutation` means
/// this operation/model combination is not opted into durable local writes.
class DwRepoWritePlan<Value> {
  const DwRepoWritePlan({
    required this.optimisticResponse,
    this.opaqueMetadata,
  });

  /// Canonical optimistic repository response returned after a durable enqueue.
  ///
  /// It must be a successful `DwApiResponse` for the same public API shape as
  /// the online boundary. `updatedModels`, when present, must be listener-safe.
  final DwApiResponse<Value> optimisticResponse;

  /// Metadata persisted with the mutation envelope, owned by the application.
  ///
  /// **The core never looks inside it and never migrates it.** It is written as
  /// given and handed back as stored, including to a build of the app older or
  /// newer than the one that wrote it. Changing its shape is a data migration
  /// the application owns; nothing here will notice that it changed.
  final Map<String, dynamic>? opaqueMetadata;
}

/// One durable transaction over [DwRepoLocalWrites].
///
/// The store opens it, the core writes what happens inside. That order is the
/// whole point: the check and the row write cannot be separated by an
/// implementation, because the implementation never sees them apart.
abstract interface class DwRepoLocalWriteTx {
  /// Reads, inside this transaction, whether [binding] is still current.
  ///
  /// Must observe the same consistent state the enqueue commits into — a read
  /// taken outside the transaction defeats the reason this method exists.
  Future<bool> isBindingCurrent(DwRepoBinding binding);

  /// Queues [mutation] inside this transaction.
  Future<void> enqueue(DwRepoMutation mutation);
}

/// The local copy of canonical `dw.repo` writes.
///
/// Implement this to make a write survive the device losing the network: an
/// outbox, a draft, an optimistic edit replayed on reconnect. Whether any
/// given write is kept is decided here — `prepareSaveMutation` and
/// `prepareDeleteMutation` return `null` for everything that stays
/// network-only.
///
/// This is not a place to observe or replace repository behaviour. A test that
/// wants to watch a save wants observability, not durability, and reaching for
/// local storage to get it forces every save to declare itself queued, which
/// is a lie about intent.
///
/// **Asymmetry with [DwRepoLocalReads], and it is deliberate.** A write opts in
/// here, per operation and model. A read opts in at the config, per query
/// (`DwRepoReadStrategy.networkFirstWithSnapshot`). They are not one paired
/// switch: a list kept offline for reading says nothing about whether saving
/// that same model is queued.
abstract interface class DwRepoLocalWrites {
  const DwRepoLocalWrites();

  /// Resolves the current runtime capability, or `null` when writes are not
  /// eligible for local storage (for example while signed out).
  Future<DwRepoBinding?> resolveBinding();

  /// Reports whether [binding] is still the exact current runtime capability.
  /// Implementations must return `false` for an inactive [binding].
  Future<bool> isBindingCurrent(DwRepoBinding binding);

  /// Returns a local save plan, or `null` when this save stays network-only.
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  });

  /// Returns a local delete plan, or `null` when this delete stays
  /// network-only.
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  });

  /// Runs [body] inside one durable transaction and returns its result.
  ///
  /// Everything [body] does — the binding check and the enqueue alike — must
  /// commit together or not at all. The danger this closes: the network drops,
  /// the write goes to the queue, and the user signs out in that exact moment.
  /// A mutation queued under a session that no longer exists is replayed on the
  /// next sign-in, on the server, as somebody else.
  ///
  /// A store that cannot open a real transaction must not implement this by
  /// running [body] against uncommitted state and hoping.
  Future<R> write<R>(Future<R> Function(DwRepoLocalWriteTx tx) body);
}
