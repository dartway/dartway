import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_pagination_params.dart';
import 'dw_pagination_strategy.dart';

class DwNoPagination implements DwPaginationStrategy {
  bool _loaded = false;

  @override
  int? get limit => null;

  @override
  DwPaginationParams buildParams() {
    return const DwPaginationParams();
  }

  @override
  void onPageLoaded(List<DwModelWrapper> data) {
    // One request returns everything there is — nothing more to load after it
    _loaded = true;
  }

  @override
  bool get hasMore => !_loaded;

  @override
  void reset() {
    _loaded = false;
  }
}
