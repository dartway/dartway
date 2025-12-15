// Define your navigation parameters as a separate enum
import 'package:dartway_router/dartway_router.dart';

import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../pages/user_detail_page.dart';

part 'zones/app_routes.dart';

// Navigation parameters - single generic enum for all types
enum AppParams<T> with NavigationParamsMixin<T> {
  userId<int>(), // int
  categoryId<int>(), // int
  searchQuery<String>(), // String
  userName<String>(), // String
  price<double>(), // double
  isEnabled<bool>(), // bool
}

final appRouterProvider = DwRouter.provider(
    DwRouter.config().addNavigationZones([AppNavigationZone.values]));
