import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/app_l10n.dart';
import '../core/router/router.dart';
import 'logic/studio_persona_switcher.dart';
import 'logic/studio_personas.dart';
import 'logic/studio_project_manifest.dart';
import 'logic/studio_session_state_provider.dart';

/// The project wiring point between the app's semantic layer and the bridge:
/// features are discovered from mounted [DwFeature] widgets and mapped onto
/// the bridge wire model.
List<StudioFeatureInfo> _mountedFeatureInfos() => [
      for (final feature in scanMountedFeatures())
        StudioFeatureInfo(
          id: feature.id,
          title: feature.title,
          description: feature.description,
        ),
    ];

/// Connects the app to DartWay Studio when it runs embedded in the Studio
/// preview frame: attaches the bridge host, reports route/session changes and
/// executes Studio's requests. Renders [child] untouched and stays inert
/// outside an iframe, so the production target is unaffected.
///
/// Lives in MaterialApp.builder — outside the router subtree — so the route
/// is observed through the router delegate, not GoRouterState.
class StudioBridgeBinding extends ConsumerStatefulWidget {
  const StudioBridgeBinding({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StudioBridgeBinding> createState() =>
      _StudioBridgeBindingState();
}

class _StudioBridgeBindingState extends ConsumerState<StudioBridgeBinding>
    implements StudioBridgeHostDelegate {
  StudioBridgeHost? _host;
  VoidCallback? _removeRouteListener;

  @override
  void initState() {
    super.initState();
    final delegate = ref.read(appRouterProvider).router.routerDelegate;

    String currentPath() {
      final configuration = delegate.currentConfiguration;
      return configuration.isEmpty ? '/' : configuration.uri.path;
    }

    _host = StudioBridgeHost.attach(
      manifest: exampleStudioManifest,
      delegate: this,
      currentPath: currentPath,
      currentSession: () => ref.read(studioSessionStateProvider),
      // The connect snapshot carries the current screen's features so a
      // freshly connected Studio sees them without waiting for navigation.
      currentFeatures: _mountedFeatureInfos,
      currentLocale: () => ref.read(appLocaleProvider).languageCode,
    );
    if (_host == null) return;

    // Features are discovered from mounted DwFeature widgets. A route change
    // may mount the new screen a frame or two later (and its content can load
    // asynchronously), so re-scan over a short window until it settles.
    void reportFeaturesSoon() {
      for (final delay in const [
        Duration(milliseconds: 50),
        Duration(milliseconds: 400),
        Duration(milliseconds: 1000),
      ]) {
        Future<void>.delayed(delay, () {
          if (!mounted) return;
          _host?.reportFeatures(currentPath(), _mountedFeatureInfos());
        });
      }
    }

    void onRouteChanged() {
      _host?.reportRoute(currentPath());
      reportFeaturesSoon();
    }

    delegate.addListener(onRouteChanged);
    _removeRouteListener = () => delegate.removeListener(onRouteChanged);

    ref.listenManual(
      studioSessionStateProvider,
      (previous, next) {
        _host?.reportSession(next);
        reportFeaturesSoon();
      },
    );

    ref.listenManual(
      appLocaleProvider,
      (previous, next) => _host?.reportLocale(next.languageCode),
    );
  }

  @override
  void dispose() {
    _removeRouteListener?.call();
    _host?.detach();
    super.dispose();
  }

  @override
  void onNavigateRequest(String path) =>
      ref.read(appRouterProvider).router.go(path);

  @override
  Future<void> onPersonaRequest(String personaId) async {
    final persona = StudioPersonas.byId(personaId);
    if (persona == null) return;
    await ref.read(studioPersonaSwitcherProvider.notifier).switchTo(persona);
  }

  @override
  Future<void> onSignOutRequest() =>
      ref.read(studioPersonaSwitcherProvider.notifier).signOutCurrentUser();

  @override
  void onLocaleRequest(String locale) =>
      ref.read(appLocaleProvider.notifier).selectLanguageCode(locale);

  @override
  Widget build(BuildContext context) => widget.child;
}
