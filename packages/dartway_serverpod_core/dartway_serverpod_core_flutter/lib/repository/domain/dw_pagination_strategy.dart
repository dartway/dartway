import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_pagination_params.dart';

abstract class DwPaginationStrategy {
  int? get limit;

  /// параметры для backend-запроса
  DwPaginationParams buildParams();

  /// вызывается после успешной загрузки
  void onPageLoaded(List<DwModelWrapper> data);

  /// есть ли ещё данные
  bool get hasMore;

  /// сброс состояния
  void reset();
}
