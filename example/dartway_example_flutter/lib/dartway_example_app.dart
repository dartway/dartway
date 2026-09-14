import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/app_l10n.dart';
import 'core/dw_core.dart';
import 'core/profile/signed_in_gate.dart';
import 'core/router/router.dart';
import 'ui_kit/ui_kit.dart';

/// The DartWay example application. All app wiring lives here; `main` only
/// supplies concrete parameters (server address, version) and runs it.
class DartwayExampleApp {
  const DartwayExampleApp({required this.baseUrl, required this.appVersion});

  /// Where the server's calls and live socket are: `http://localhost:8080`.
  final Uri baseUrl;

  /// This build, `<semver>+<build>`: shown in the corner of every page and in
  /// error reports, and sent with every call.
  final String appVersion;

  void run() {
    // Built here, started by the runner: `dw.init()` starts the plugins and
    // reads the stored session, without waiting for the server — a start
    // offline is a start.
    createExampleDwCore(baseUrl: baseUrl, appVersion: appVersion);

    DwAppRunner(
      // No onError: uncaught errors flow into the dw pipeline, where the app's
      // `onErrorReport` sorts them out.
      appInitializers: [dw.init],
      supportedLocales: AppLocalizations.supportedLocales,
      child: const ExampleApp(),
    ).run();
  }
}

/// The application widget: router, localizations, theme, notifications and
/// the profile gate. A widget test pumps it inside its own `ProviderScope`
/// once it has built a core.
class ExampleApp extends ConsumerWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'DartWay Example',
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, child) => DwNotificationsListener(
        handlers: {DwUiNotification: DwUiNotificationHandler()},
        child: SignedInGate(child: child ?? const SizedBox.shrink()),
      ),
      routerConfig: router.router,
    );
  }
}
