import 'package:dartway_flutter/dartway_flutter.dart';

import 'dw_repo_local_reads.dart';
import 'dw_repo_local_writes.dart';

/// The plugin that gives `dw.repo` a local copy of its reads and writes.
///
/// Local storage arrives with the core and lives exactly as long as it:
///
/// ```dart
/// dw = DwCore(
///   config: ..., client: ..., dwAlerts: ..., getUserId: ...,
///   plugins: [DwOffline(store: MyLocalStore())],
/// );
/// ```
///
/// There is no setter, and that is the fix rather than an omission. A store
/// assigned after startup outlives the core it was attached to: recreate the
/// core and the old store is still there, still current, still accepting
/// mutations — and nothing fails, the writes simply go somewhere that no longer
/// belongs to anybody. Declaring it here makes that state unreachable.
///
/// Both halves are optional: a store may keep reads without keeping writes, or
/// the other way round. Returning `null` from either leaves that half of
/// `dw.repo` network-only.
///
/// Only one plugin may claim this role. Two of them is a wiring mistake the
/// core reports at the first read or write rather than silently picking one.
abstract class DwRepoLocalStorePlugin extends DwPlugin {
  const DwRepoLocalStorePlugin();

  /// The local copy of reads, or `null` while reads stay network-only.
  DwRepoLocalReads? get localReads;

  /// The local copy of writes, or `null` while writes stay network-only.
  DwRepoLocalWrites? get localWrites;
}
