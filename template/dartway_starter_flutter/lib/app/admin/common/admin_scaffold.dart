import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/router/router.dart';
import '../../../ui_kit/ui_kit.dart';

/// Shell of the admin zone. Deliberately not wrapped in the device frame:
/// the admin panel is a working surface, so it uses the full viewport and
/// adapts — a navigation rail on wide screens, a bottom bar on narrow ones.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.title, required this.body});

  static const _wideBreakpoint = 700.0;

  final String title;
  final Widget body;

  static const _sections = [
    (route: AdminNavigationZone.admin, icon: Icons.insights),
    (route: AdminNavigationZone.users, icon: Icons.people),
    (route: AdminNavigationZone.settings, icon: Icons.settings),
  ];

  String _sectionLabel(AppLocalizations l10n, AdminNavigationZone route) =>
      switch (route) {
        AdminNavigationZone.admin => l10n.adminDashboard,
        AdminNavigationZone.users => l10n.adminUsers,
        AdminNavigationZone.settings => l10n.adminSettings,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Deepest active route wins: the zone root matches every admin location,
    // so the last match is the specific section.
    final lastActive =
        _sections.lastIndexWhere((s) => s.route.isActive(context));
    final activeIndex = lastActive < 0 ? 0 : lastActive;

    void goToSection(int index) =>
        GoRouter.of(context).goNamed(_sections[index].route.name);

    final appBar = AppBar(
      title: AppText.title(title),
      leading: IconButton(
        tooltip: l10n.backToApp,
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            GoRouter.of(context).goNamed(AppNavigationZone.home.name),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: activeIndex,
                  onDestinationSelected: goToSection,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final section in _sections)
                      NavigationRailDestination(
                        icon: Icon(section.icon),
                        label: Text(_sectionLabel(l10n, section.route)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: body,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: body,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: activeIndex,
            onDestinationSelected: goToSection,
            destinations: [
              for (final section in _sections)
                NavigationDestination(
                  icon: Icon(section.icon),
                  label: _sectionLabel(l10n, section.route),
                ),
            ],
          ),
        );
      },
    );
  }
}
