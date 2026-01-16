// Define your navigation parameters as a separate enum
import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/book_detail_page.dart';
import '../app/book_list_page.dart';
import '../app/profile_page.dart';
import '../auth/auth_page.dart';
import 'router_refresh_notifier.dart';

part 'zones/app_routes.dart';
part 'zones/auth_routes.dart';

enum AppParams<T> with DwNavigationParamsMixin<T> { bookId<int>() }

final appRouterProvider = Provider<DwRouter<RouterRefreshNotifier>>((ref) {
  final notifier = ref.watch(routerRefreshNotifierProvider);

  return DwRouter<RouterRefreshNotifier>(
    refreshListenable: notifier,
    navigationZones: [AppRoutes.values, AuthRoutes.values],
    pageBuilder: DwPageBuilder.fade,
    options: DwGoRouterOptions(
      initialLocation: AppRoutes.catalog.fullPath,
      debugLogDiagnostics: true,
    ),
  );
});
