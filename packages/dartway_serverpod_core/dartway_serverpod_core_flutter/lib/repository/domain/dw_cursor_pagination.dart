import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_pagination_params.dart';
import 'dw_pagination_strategy.dart';

class DwCursorPagination implements DwPaginationStrategy {
  final int limit;
  int? _oldestId;
  bool _hasMore = true;

  DwCursorPagination({required this.limit});

  @override
  DwPaginationParams buildParams() {
    return DwPaginationParams(
      beforeId: _oldestId,
      limit: limit,
    );
  }

  @override
  void onPageLoaded(List<DwModelWrapper> data) {
    if (data.isEmpty) {
      _hasMore = false;
      return;
    }

    _oldestId = data
        .where((e) => e.modelId != null)
        .map((e) => e.modelId!)
        .reduce((a, b) => a < b ? a : b);

    _hasMore = data.length == limit;
  }

  @override
  bool get hasMore => _hasMore;

  @override
  void reset() {
    _oldestId = null;
    _hasMore = true;
  }
}
