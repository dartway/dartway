import 'package:flutter/material.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

/// App page scaffold. Pages live in the app navigation zone, which is only
/// reachable when signed in (see the router redirect guards), so no per-page
/// auth gating is needed here — `SignedInGate` loads the profile first.
class AppScaffold extends StatelessWidget {
  const AppScaffold.main({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bodyInsets = const EdgeInsets.all(16),
  }) : showBottomNavigationBar = true;

  const AppScaffold.inner({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bodyInsets = const EdgeInsets.all(16),
  }) : showBottomNavigationBar = false;

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final EdgeInsets bodyInsets;
  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return DeviceFrameShell(
      body: Scaffold(
        appBar: appBar,
        body: Stack(
          children: [
            Padding(
              padding: bodyInsets,
              child: SizedBox.expand(child: body),
            ),
            const Positioned(right: 4, bottom: 4, child: AppVersionLabel()),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: showBottomNavigationBar
            ? const _AppBottomNavigationBar()
            : null,
      ),
    );
  }
}

class _AppBottomNavigationBar extends StatelessWidget {
  const _AppBottomNavigationBar();

  static const _tabs = [
    (route: AppNavigationZone.home, icon: Icons.home_outlined),
    (route: AppNavigationZone.profile, icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    // The deepest active route wins: the zone root matches every location.
    final lastActive = _tabs.lastIndexWhere(
      (tab) => tab.route.isActive(context),
    );

    return BottomNavigationBar(
      currentIndex: lastActive < 0 ? 0 : lastActive,
      onTap: (index) => GoRouter.of(context).goNamed(_tabs[index].route.name),
      type: BottomNavigationBarType.fixed,
      // Colours come from AppTheme.light — set once for the whole app, not
      // re-picked by every widget that happens to need them.
      showUnselectedLabels: true,
      items: [
        for (final tab in _tabs)
          BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: switch (tab.route) {
              AppNavigationZone.home => context.l10n.tabHome,
              AppNavigationZone.profile => context.l10n.tabProfile,
            },
          ),
      ],
    );
  }
}
