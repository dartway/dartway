import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

/// Optional feature content for the scaffold's quick-entry surface.
/// The feature owns reads, dependent-card readiness and draft state. Attach
/// the supplied focus node to its composer; keep drafts outside the
/// dismissible subtree.
class AppQuickSheetEntry {
  const AppQuickSheetEntry({
    required this.openLabel,
    required this.dismissLabel,
    required this.builder,
  });

  final String openLabel;
  final String dismissLabel;
  final Widget Function(
    BuildContext context,
    FocusNode inputFocus,
    VoidCallback dismiss,
  )
  builder;
}

/// App page scaffold. Pages live in the app navigation zone, which is only
/// reachable when signed in (see the router redirect guards), so no per-page
/// auth gating is needed here — `SignedInGate` loads the profile first.
class AppScaffold extends StatelessWidget {
  const AppScaffold.main({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.quickEntry,
    this.bodyInsets = const EdgeInsets.all(AppSpace.s16),
  }) : showBottomNavigationBar = true;

  const AppScaffold.inner({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bodyInsets = const EdgeInsets.all(AppSpace.s16),
  }) : showBottomNavigationBar = false,
       quickEntry = null;

  final AppQuickSheetEntry? quickEntry;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final EdgeInsets bodyInsets;
  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) =>
      DeviceFrameShell(body: _AppScaffoldContent(scaffold: this));
}

// All keyboard and safe-area measurements belong to the framed viewport too.
class _AppScaffoldContent extends HookWidget {
  const _AppScaffoldContent({required this.scaffold});

  final AppScaffold scaffold;

  @override
  Widget build(BuildContext context) {
    final sheetOpen = useState(false);
    final inputFocus = useFocusNode();
    final primerFocus = useFocusNode();
    final revealingNavigation = useRef(false);
    final wasOpen = usePrevious(sheetOpen.value);
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (wasOpen == true && !sheetOpen.value) revealingNavigation.value = true;
    if (sheetOpen.value || !keyboardUp) revealingNavigation.value = false;
    final navigationCovered = keyboardUp && !revealingNavigation.value;
    void dismiss() => sheetOpen.value = false;
    void toggle() {
      if (sheetOpen.value) {
        dismiss();
        return;
      }
      // Safari requires focus synchronously inside the gesture. The real
      // composer mounts next frame; transfer focus once it exists.
      if (kIsWeb) primerFocus.requestFocus();
      sheetOpen.value = true;
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && sheetOpen.value) inputFocus.requestFocus();
        });
      }
    }

    final navigationHeight = AppQuickSheetOverlay.navigationHeightOf(context);
    final page = Scaffold(
      appBar: scaffold.appBar,
      body: Stack(
        children: [
          Padding(
            padding: scaffold.bodyInsets,
            child: SizedBox.expand(child: scaffold.body),
          ),
          if (!scaffold.showBottomNavigationBar)
            const Positioned(right: 4, bottom: 4, child: AppVersionLabel()),
        ],
      ),
      floatingActionButton: scaffold.floatingActionButton,
      bottomNavigationBar: scaffold.showBottomNavigationBar && !keyboardUp
          ? SizedBox(
              height: navigationHeight + AppQuickSheetOverlay.footerHeight,
            )
          : null,
    );
    if (!scaffold.showBottomNavigationBar) return page;

    return Stack(
      children: [
        page,
        Positioned.fill(
          child: AppNavigationKeyboardScope(
            isCovered: navigationCovered,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _AppBottomNavigationBar(onNavigate: dismiss),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navigationHeight,
                  child: const SizedBox(
                    height: AppQuickSheetOverlay.footerHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppVersionLabel(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (scaffold.quickEntry case final entry?) ...[
          Positioned.fill(
            child: AppQuickSheetOverlay(
              isOpen: sheetOpen.value,
              onDismiss: dismiss,
              dismissLabel: entry.dismissLabel,
              onInputReady: kIsWeb ? null : inputFocus.requestFocus,
              child: Builder(
                builder: (context) =>
                    entry.builder(context, inputFocus, dismiss),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.viewPaddingOf(context).bottom,
            left: 0,
            right: 0,
            child: AppNavigationKeyboardScope(
              isCovered: navigationCovered,
              child: Center(
                child: IconButton.filled(
                  tooltip: sheetOpen.value
                      ? entry.dismissLabel
                      : entry.openLabel,
                  onPressed: toggle,
                  icon: Icon(sheetOpen.value ? Icons.close : Icons.add),
                ),
              ),
            ),
          ),
          if (kIsWeb)
            Positioned(
              left: 0,
              bottom: 0,
              width: 1,
              height: 1,
              child: AppKeyboardPrimer(focusNode: primerFocus),
            ),
        ],
      ],
    );
  }
}

class _AppBottomNavigationBar extends StatelessWidget {
  const _AppBottomNavigationBar({required this.onNavigate});

  final VoidCallback onNavigate;

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
      onTap: (index) {
        onNavigate();
        GoRouter.of(context).goNamed(_tabs[index].route.name);
      },
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
