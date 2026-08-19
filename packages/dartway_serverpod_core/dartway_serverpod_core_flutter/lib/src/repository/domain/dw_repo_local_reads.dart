import 'dw_repo_binding.dart';
import 'dw_repo_query_key.dart';

/// The source a repository read was resolved from.
enum DwRepoReadOrigin { network, localSnapshot }

/// The outcome of offering one response to local storage.
enum DwRepoReadSnapshotStoreResult {
  stored,

  /// The binding is current, but this query is deliberately not kept locally.
  ignored,

  /// The binding stopped being current, so nothing was written.
  stale,
}

/// A persistence-safe envelope for one serialized [DwApiResponse] snapshot.
///
/// [schemaVersion] belongs to the envelope rather than to a storage
/// implementation, so a future store can reject incompatible rows before
/// deserializing their response payload.
class DwRepoReadSnapshot {
  const DwRepoReadSnapshot({
    required this.schemaVersion,
    required this.scope,
    required this.responseJson,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final DwRepoScope scope;
  final Map<String, dynamic> responseJson;
}

/// The local copy of canonical `dw.repo` reads.
///
/// Implement this to keep repository responses on the device: offline reading,
/// a warm start, a draft that must survive the process. Reads never reach it
/// unless a config asks for it by name — see the note on asymmetry below.
///
/// This is not a place to observe or replace repository behaviour. A test that
/// wants to watch a request wants observability, not durability, and reaching
/// for local storage to get it makes every read claim it should be kept, which
/// is a lie about intent.
///
/// **Asymmetry with [DwRepoLocalWrites], and it is deliberate.** A read opts in
/// per query, at the config: `DwRepoReadStrategy.networkFirstWithSnapshot`. A
/// write opts in inside the store, per operation and model, by returning a plan
/// from `prepareSaveMutation` / `prepareDeleteMutation`. Reading them as one
/// paired switch is the natural mistake: a config that keeps its list offline
/// says nothing about whether saving that same model is queued.
///
/// Implementations key snapshots by the stable scope of a [DwRepoBinding] and a
/// [DwRepoQueryKey]. A snapshot returned for a different scope is rejected by
/// the core before it can reach callers.
abstract interface class DwRepoLocalReads {
  const DwRepoLocalReads();

  /// Resolves the current runtime capability, or `null` when reads are not
  /// eligible for local storage (for example while signed out).
  Future<DwRepoBinding?> resolveBinding();

  /// Reports whether [binding] is still the exact current runtime capability.
  /// Implementations must return `false` for an inactive [binding].
  Future<bool> isBindingCurrent(DwRepoBinding binding);

  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  });

  /// Atomically writes only while [binding] is current at the commit point.
  ///
  /// A persistent store must implement this condition transactionally with the
  /// row write; a pre-write read of [isBindingCurrent] is not enough. Return
  /// [DwRepoReadSnapshotStoreResult.stale] without committing when the capability
  /// changed.
  Future<DwRepoReadSnapshotStoreResult> storeSnapshotIfCurrent<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  });
}

/// A processed canonical read along with the source that supplied it.
class DwRepoReadResult<Value> {
  const DwRepoReadResult({required this.value, required this.origin});

  final Value? value;
  final DwRepoReadOrigin origin;
}
