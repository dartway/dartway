// Define your navigation parameters as a separate enum
import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

import '../app/book_detail_page.dart';
import '../app/book_list_page.dart';
import '../app/profile_page.dart';
import '../auth/auth_page.dart';
import '../core/app_session_notifier.dart';

part 'zones/app_routes.dart';
part 'zones/auth_routes.dart';

// Navigation parameters - single generic enum for all types
enum AppParams<T> with DwNavigationParamsMixin<T> { bookId<int>() }

final DwRouter<AppSession> appRouter = DwRouter(
  refreshListenable: AppSession.instance,
  navigationZones: <List<DwNavigationRoute<AppSession>>>[
    AppRoutes.values,
    AuthRoutes.values,
  ],
  pageBuilder: (context, key, child) => DwPageBuilder.fade(context, key, child),

  options: DwGoRouterOptions(
    initialLocation: AppRoutes.catalog.fullPath,
    debugLogDiagnostics: true,
    // errorBuilder: (context, state) =>
    //     const DwNotFoundPageWidget(redirectRoute: AppRoutes.catalog),
  ),
);
