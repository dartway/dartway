import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../calls/dw_bound_watch.dart';

/// Whole-list reads under the current server's bound policy.
extension DwListRead<T extends DwDataObject> on DwListRequest<T> {
  /// Reads at most [fetchLimit] rows on the normal path. [read] must apply its
  /// nullable limit to the same query each time: null means no limit.
  ///
  /// Overflow fails loudly in tests and strict development servers. Production
  /// re-reads once without a limit; the endpoint serves the whole answer and
  /// logs its true count and encoded size through the throttled bound warning.
  /// Only use this for lists bounded by the domain; history belongs in pages.
  Future<List<R>> readWhole<R>(
    Future<List<R>> Function(int? limit) read,
  ) async {
    final bounds = DwBoundWatch.current;
    final rows = await read(fetchLimit);
    if (rows.length <= maxItems) return rows;
    bounds.checkProbe(this, rows.length);
    return read(null);
  }
}
