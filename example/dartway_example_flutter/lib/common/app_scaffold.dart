import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/core/user_profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// App page scaffold. Pages live in the app navigation zone, which is only
/// reachable when signed in (see the router redirect guards), so no per-page
/// auth gating is needed here — the root [DwUserAsyncScope] loads the profile.
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
    return DwDeviceFrame(
      body: Scaffold(
        appBar: appBar,
        body: Stack(
          children: [
            Padding(
              padding: bodyInsets,
              child: SizedBox.expand(child: body),
            ),
            const Positioned(
              right: 4,
              bottom: 4,
              child: AppVersionLabel(),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar:
            showBottomNavigationBar ? const _AppBottomNavigationBar() : null,
      ),
    );
  }
}

class _AppBottomNavigationBar extends ConsumerWidget {
  const _AppBottomNavigationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The chat tab is staff-only in the UI; the server-side access filter is
    // the real protection.
    final isStaffMember = ref.watchUserProfile.isStaffMember;

    final tabs = [
      (route: AppNavigationZone.schedule, icon: Icons.calendar_month),
      (route: AppNavigationZone.bookings, icon: Icons.event_available),
      (route: AppNavigationZone.news, icon: Icons.article),
      if (isStaffMember) (route: AppNavigationZone.chat, icon: Icons.chat),
      (route: AppNavigationZone.profile, icon: Icons.person),
    ];
    final currentIndex = tabs.indexWhere((tab) => tab.route.isActive(context));

    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      onTap: (index) => GoRouter.of(context).goNamed(tabs[index].route.name),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.outline,
      showUnselectedLabels: true,
      items: [
        for (final tab in tabs)
          BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: _tabLabel(context.l10n, tab.route),
          ),
      ],
    );
  }

  String _tabLabel(AppLocalizations l10n, AppNavigationZone route) =>
      switch (route) {
        AppNavigationZone.schedule => l10n.tabSchedule,
        AppNavigationZone.bookings => l10n.tabBookings,
        AppNavigationZone.news => l10n.tabNews,
        AppNavigationZone.chat => l10n.tabChat,
        _ => l10n.tabProfile,
      };
}
