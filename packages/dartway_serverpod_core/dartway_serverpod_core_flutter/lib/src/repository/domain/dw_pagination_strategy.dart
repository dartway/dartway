import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_pagination_params.dart';

/// How a list asks the backend for its next page and decides when to stop.
abstract class DwPaginationStrategy {
  int? get limit;

  /// The parameters for the next backend request.
  DwPaginationParams buildParams();

  /// Called after a page loads successfully.
  void onPageLoaded(List<DwModelWrapper> data);

  /// Whether there is more to load.
  bool get hasMore;

  /// Returns the strategy to its initial state.
  void reset();
}
