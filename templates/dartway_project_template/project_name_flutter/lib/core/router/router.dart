import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/app/home/home_page/home_page.dart';
import 'package:project_name_flutter/app/profile/profile_page/profile_page.dart';
import 'package:project_name_flutter/auth/auth_page.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';

part 'navigation_zones/app_navigation_zone.dart';
part 'navigation_zones/auth_navigation_zone.dart';

enum AppNavigationParams<T> with NavigationParamsMixin<T> {
  userId<int>(),
  postId<int>(),
  chatId<int>(),
}

final appRouterProvider = DwRouter.provider(
  DwRouter.config().addNavigationZones([
    AuthNavigationZone.values,
    AppNavigationZone.values,
  ]).setRedirectsProvider(
    Provider<RedirectsStateModel>(
      (ref) {
        debugPrint("rebuilding redirects");
        final userProfile = ref.watchMaybeUserProfile;

        if (userProfile != null) {
          return RedirectsStateModel(
            redirects: Map.fromEntries(
              <NavigationZoneRoute>[
                ...AuthNavigationZone.values,
              ].map(
                (e) => MapEntry(
                  e,
                  AppNavigationZone.home,
                ),
              ),
            ),
          );
        } else {
          return RedirectsStateModel(
            redirects: Map.fromEntries(
              <NavigationZoneRoute>[
                ...AppNavigationZone.values,
              ].map(
                (e) => MapEntry(
                  e,
                  AuthNavigationZone.auth,
                ),
              ),
            ),
          );
        }
      },
      dependencies: [userProfileProvider],
    ),
  ),
);
