import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/router/router.dart';

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
            Positioned(
              right: 4,
              bottom: 4,
              child: Text(
                exampleAppVersion,
                style: const TextStyle(fontSize: 8, color: Colors.blueGrey),
              ),
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

class _AppBottomNavigationBar extends StatelessWidget {
  const _AppBottomNavigationBar();

  @override
  Widget build(BuildContext context) {
    const tabs = [AppNavigationZone.home, AppNavigationZone.profile];
    final currentIndex = tabs.indexWhere((tab) => tab.isActive(context));

    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      onTap: (index) => GoRouter.of(context).goNamed(tabs[index].name),
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.lightBlueAccent,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Profile'),
      ],
    );
  }
}
