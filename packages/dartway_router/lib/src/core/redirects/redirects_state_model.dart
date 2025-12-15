import 'package:freezed_annotation/freezed_annotation.dart';

import '../navigation_zones/navigation_zone_route.dart';

// part 'dw_redirects_model.g.dart';
part 'redirects_state_model.freezed.dart';

@freezed
abstract class RedirectsStateModel with _$RedirectsStateModel {
  const factory RedirectsStateModel({
    required Map<NavigationZoneRoute, NavigationZoneRoute> redirects,
  }) = _RedirectsStateModel;
}
