import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_pagination_params.dart';
import 'dw_pagination_strategy.dart';

class DwOffsetPagination implements DwPaginationStrategy {
  int _nextPage = 0;
  final int pageSize;
  bool _hasMore = true;

  DwOffsetPagination(this.pageSize);

  @override
  DwPaginationParams buildParams() {
    return DwPaginationParams(
      offset: _nextPage * pageSize,
      limit: pageSize,
    );
  }

  @override
  void onPageLoaded(List<DwModelWrapper> data) {
    _nextPage++;
    _hasMore = data.length == pageSize;
  }

  @override
  bool get hasMore => _hasMore;

  @override
  int get limit => pageSize;

  @override
  void reset() {
    _nextPage = 0;
    _hasMore = true;
  }
}
