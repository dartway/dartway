import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';

import 'core/app_l10n.dart';
import 'core/default_models.dart';
import 'core/dw_core.dart';
import 'core/router/router.dart';
import 'core/studio/logic/studio_project_manifest.dart';
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
      // No onError: uncaught errors flow into the dw pipeline, where DwCore
      // filters connection blips and alerts everything else with app context
      // (route, mounted features, action, user) — zero-config alerting.
      appInitializers: [
        () =>
            dw.initDwCore(initRepositoryFunction: DefaultModels.initRepository),
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
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Awesome DartWay Project',
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, child) {
        // The Studio binding is inert unless the app runs embedded in the
        // DartWay Studio preview frame. Everything mechanical about it — the
        // handshake, the reports, the persona flow — belongs to the package;
        // what stays here is only what this app alone can answer.
        final appChild = DwStudioBinding(
          core: dw,
          manifest: exampleStudioManifest,
          router: router,
          // Which profile field is the identity Studio matches its personas
          // against, and which one names the user on screen.
          describeUser: (profile) =>
              DwStudioUser(identifier: profile.phone, label: profile.firstName),
          locale: DwStudioLocale(
            provider: appLocaleProvider,
            select: (languageCode) => ref
                .read(appLocaleProvider.notifier)
                .selectLanguageCode(languageCode),
          ),
          // Accept only a Studio presenting a token signed for this
          // deployment's own address, so a token taken from here is useless
          // anywhere else. Empty define = local dev, no check.
          validateAccessToken: studioSignedAccessValidator(
            const String.fromEnvironment('STUDIO_APP_ORIGIN'),
          ),
          child: DwUserAsyncScope<UserProfile>(
            skipOnSignIn: false,
            whenProfileReadyCallback: (_) {},
            // Subscribed once, for the whole app: anything a CRUD config
            // broadcasts to this channel (`broadcastTo:` on the server) is
            // routed by type into every `dw.repo.modelList<T>()` on screen.
            child: DwChannelSubscriptionWidget(
              channel: DwCoreConst.publicUpdatesChannel,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );

        return DwNotificationsListener(
          handlers: {DwUiNotification: DwUiNotificationHandler()},
          child: appChild,
        );
      },
      routerConfig: router.router,
    );
  }
}
