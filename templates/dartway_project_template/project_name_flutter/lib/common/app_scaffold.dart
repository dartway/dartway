import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/build_info.dart';
import 'package:project_name_flutter/core/router/router.dart';

import '../core/user_profile_provider.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold.main({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bodyInsets = const EdgeInsets.all(16),
    this.requireUser = true,
  }) : showBottomNavigationBar = true;

  const AppScaffold.inner({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bodyInsets = const EdgeInsets.all(16),
    this.requireUser = true,
  }) : showBottomNavigationBar = false;

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final EdgeInsets bodyInsets;

  final bool showBottomNavigationBar;
  final bool requireUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DwDeviceFrame(
      body: ConditionalParentWidget(
        condition: requireUser,
        parentBuilder: (child) => SignedInUserScope<UserProfile>(
          userProfileProvider: userProfileProvider,
          child: child,
        ),
        child: Scaffold(
          appBar: appBar,
          body: Stack(
            children: [
              Padding(
                padding: bodyInsets,
                child: SizedBox.expand(
                  child: body,
                ),
              ),
              // if (kDebugMode)
              const Positioned(
                right: 4,
                bottom: 4,
                child: Text(
                  BuildInfo.version,
                  style: TextStyle(fontSize: 8, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: showBottomNavigationBar
              ? const DwBottomNavigationBar(
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    selectedItemColor: Colors.blue,
                    unselectedItemColor: Colors.lightBlueAccent,
                    showUnselectedLabels: true,
                  ),
                  menuItems: [
                    DwMenuItem.icon(
                      route: AppNavigationZone.home,
                      displayTitle: 'Home',
                      iconData: Icons.home,
                    ),
                    DwMenuItem.icon(
                      route: AppNavigationZone.profile,
                      displayTitle: 'Profile',
                      iconData: Icons.settings,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
