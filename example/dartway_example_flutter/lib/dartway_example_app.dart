import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';

import 'core/default_models.dart';
import 'core/dw_core.dart';
import 'core/router/router.dart';
import 'ui_kit/ui_kit.dart';

/// The DartWay example application. All app wiring lives here; `main` only
/// supplies concrete development parameters (backend URL, version) and runs it.
class DartwayExampleApp {
  const DartwayExampleApp({
    required this.backendUrl,
    this.appVersion = 'local',
  });

  /// Backend base URL the Serverpod client connects to.
  final String backendUrl;

  /// Version label shown in the corner of every page.
  final String appVersion;

  void run() {
    exampleAppVersion = appVersion;
    initExampleDwCore(backendUrl: backendUrl);

    DwAppRunner(
      appInitializers: [
        () => dw.initDwCore(
          initRepositoryFunction: DefaultModels.initRepository,
        ),
      ],
      child: const _ExampleMaterialApp(),
    ).run();
  }
}

class _ExampleMaterialApp extends ConsumerWidget {
  const _ExampleMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Awesome DartWay Project',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 4, 49, 57),
        ),
        extensions: const [
          DwFlutterTheme(
            multiLinkText: AppText.body,
            multiLinkTextLink: AppText.link,
            primaryButton: AppButton.primary,
            secondaryButton: AppButton.secondary,
            textButton: AppButton.text,
          ),
        ],
      ),
      builder: (context, child) => DwNotificationsListener(
        handlers: {DwUiNotification: DwUiNotificationHandler()},
        child: DwUserAsyncScope<UserProfile>(
          skipOnSignIn: false,
          whenProfileReadyCallback: (_) {},
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerConfig: router.router,
    );
  }
}
