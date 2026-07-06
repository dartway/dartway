import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';

import 'core/default_models.dart';
import 'core/dw_core.dart';
import 'core/router/router.dart';
import 'studio/studio_bridge_binding.dart';
import 'ui_kit/ui_kit.dart';

/// Wraps the running app with an extra shell (used by the showcase target).
typedef ShowcaseShellBuilder = Widget Function(
  BuildContext context,
  Widget appChild,
);

/// The DartWay example application. All app wiring lives here; `main` only
/// supplies concrete development parameters (backend URL, version) and runs it.
class DartwayExampleApp {
  const DartwayExampleApp({
    required this.backendUrl,
    this.appVersion = 'local',
    this.showcaseShellBuilder,
  });

  /// Backend base URL the Serverpod client connects to.
  final String backendUrl;

  /// Version label shown in the corner of every page.
  final String appVersion;

  /// Null in production (`main.dart`): the app renders exactly as before.
  /// The showcase target (`main_showcase.dart`) injects its chrome here.
  final ShowcaseShellBuilder? showcaseShellBuilder;

  void run() {
    exampleAppVersion = appVersion;
    initExampleDwCore(backendUrl: backendUrl);

    DwAppRunner(
      // Zone-level connection errors (e.g. the streaming retry) are swallowed;
      // real errors still reach the report sink. Real apps route the latter to
      // their alert sink instead of debugPrint.
      onError: dwConnectionAwareErrorHandler(
        onConnectionError: (error) =>
            debugPrint('[zone] swallowed connection error: $error'),
        onUnexpectedError: (error, st) => debugPrint('[zone] $error\n$st'),
      ),
      appInitializers: [
        () => dw.initDwCore(
          initRepositoryFunction: DefaultModels.initRepository,
        ),
      ],
      child: _ExampleMaterialApp(showcaseShellBuilder: showcaseShellBuilder),
    ).run();
  }
}

class _ExampleMaterialApp extends ConsumerWidget {
  const _ExampleMaterialApp({this.showcaseShellBuilder});

  final ShowcaseShellBuilder? showcaseShellBuilder;

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
      builder: (context, child) {
        // The Studio bridge is inert unless the app runs embedded in the
        // DartWay Studio preview frame.
        final appChild = StudioBridgeBinding(
          child: DwUserAsyncScope<UserProfile>(
            skipOnSignIn: false,
            whenProfileReadyCallback: (_) {},
            child: child ?? const SizedBox.shrink(),
          ),
        );

        return DwNotificationsListener(
          handlers: {DwUiNotification: DwUiNotificationHandler()},
          child: showcaseShellBuilder?.call(context, appChild) ?? appChild,
        );
      },
      routerConfig: router.router,
    );
  }
}
