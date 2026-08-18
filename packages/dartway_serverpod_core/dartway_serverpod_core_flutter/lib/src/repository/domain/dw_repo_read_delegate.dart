import 'dw_repo_query_key.dart';
import 'dw_repo_binding.dart';

/// The source from which a repository read was resolved.
enum DwRepoReadOrigin { network, offlineSnapshot }

typedef DwRepoReadScope = DwRepoScope;
typedef DwRepoReadBinding = DwRepoBinding;

/// An opaque, in-memory capability for one authenticated read binding.
///
/// A delegate must issue a fresh instance for every scope transition, even
/// when the persistent [scope.storageKey] is the same (logout/login ABA). It
/// is deliberately not persisted with snapshots, so app restart does not make
/// valid rows incompatible with a new runtime binding.
enum DwRepoReadSnapshotStoreResult {
  stored,

  /// The binding is current, but this query is intentionally not persisted.
  ignored,

  stale,
}

/// A persistence-safe envelope for one serialized [DwApiResponse] snapshot.
///
/// [schemaVersion] intentionally belongs to the envelope, rather than to a
/// storage implementation. A future store can reject incompatible rows before
/// deserializing their response payload.
class DwRepoReadSnapshot {
  const DwRepoReadSnapshot({
    required this.schemaVersion,
    required this.scope,
    required this.responseJson,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final DwRepoReadScope scope;
  final Map<String, dynamic> responseJson;
}

/// The optional persistence boundary for canonical `dw.repo` reads.
///
/// Implementations resolve an opaque authenticated [DwRepoReadBinding] and
/// must key snapshots by its stable scope and [DwRepoQueryKey]. Returning a
/// snapshot for a different scope is rejected by core before it can reach
/// callers.
abstract interface class DwRepoReadDelegate {
  const DwRepoReadDelegate();

  /// Resolves the current runtime capability, or `null` when reads are not
  /// eligible for persistence (for example while signed out).
  Future<DwRepoReadBinding?> resolveBinding();

  /// Reports whether [binding] is still the exact current runtime capability.
  /// Implementations must return `false` for an inactive [binding].
  Future<bool> isBindingCurrent(DwRepoReadBinding binding);

  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  });

  /// Atomically writes only while [binding] is current at the commit point.
  ///
  /// Persistent delegates must implement this condition transactionally with
  /// the row write; a pre-write read of [isBindingCurrent] is insufficient.
  /// Return [DwRepoReadSnapshotStoreResult.stale] without committing if the
  /// capability changed. Task 10's real store must provide this same atomic
  /// guarantee.
  Future<DwRepoReadSnapshotStoreResult> storeSnapshotIfCurrent<Model>({
    required DwRepoReadBinding binding,
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
