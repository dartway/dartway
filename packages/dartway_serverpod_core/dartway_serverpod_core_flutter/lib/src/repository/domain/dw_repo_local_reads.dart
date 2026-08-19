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

  /// Runs [body] inside one durable transaction and returns its result.
  ///
  /// Keeping a read is a write, and it carries the same danger as any other:
  /// the response arrives, the core offers it to the store, and the user signs
  /// out in that exact moment. A snapshot committed after the sign-out survives
  /// the purge that was supposed to remove it — rows of a session that ended,
  /// still on the device.
  ///
  /// So the store opens the transaction and the core writes what happens
  /// inside it. The binding check and the row write cannot be separated by an
  /// implementation, because the implementation never sees them apart.
  ///
  /// Named [keep] rather than `write` on purpose: one class may implement both
  /// this contract and [DwRepoLocalWrites], and two methods of the same name
  /// taking different transactions cannot coexist.
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body);
}

/// One durable transaction over [DwRepoLocalReads].
///
/// The store opens it, the core writes what happens inside. Same shape as
/// [DwRepoLocalWriteTx], and for the same reason.
abstract interface class DwRepoLocalReadTx {
  /// Reads, inside this transaction, whether [binding] is still current.
  ///
  /// Must observe the same consistent state the snapshot commits into — a read
  /// taken outside the transaction defeats the reason this method exists.
  Future<bool> isBindingCurrent(DwRepoBinding binding);

  /// Keeps [snapshot] under [queryKey], and reports whether it kept it.
  ///
  /// `false` is an ordinary answer, not a failure: a store decides for itself
  /// which of the queries offered to it are worth keeping, and the core turns
  /// that into [DwRepoReadSnapshotStoreResult.ignored]. Saying no is how a
  /// store keeps a handful of screens offline instead of the whole backend.
  Future<bool> storeSnapshot<Model>({
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
