import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app_l10n.dart';
import '../router/router.dart';
import 'logic/studio_persona_switcher.dart';
import 'logic/studio_project_manifest.dart';
import 'logic/studio_session_state_provider.dart';

/// The project wiring point between the app's semantic layer and the bridge:
/// features are discovered from mounted [DwFeature] widgets and mapped onto
/// the bridge wire model.
StudioFeatureInfo _toWireModel(DwFeatureSpec feature) => StudioFeatureInfo(
      id: feature.id,
      title: feature.title,
      purpose: feature.purpose,
      behaviors: feature.behaviors,
      requirements: feature.requirements,
      implementationNotes: feature.implementationNotes,
      knownIssues: feature.knownIssues,
    );

List<StudioFeatureInfo> _mountedFeatureInfos() =>
    [for (final feature in DwFeature.scanMounted()) _toWireModel(feature)];

/// Answers Studio's "pencil" tap-to-inspect flow: the point arrives as
/// fractions of this app's own logical viewport, converted here (not by
/// Studio, which only knows how it is displaying the preview, framed or
/// scaled) into an [Offset] [DwFeature.hitTest] can use.
StudioFeatureInfo? _featureAtPoint(
  double horizontalFraction,
  double verticalFraction,
) {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final feature = DwFeature.hitTest(
    Offset(
      horizontalFraction * logicalSize.width,
      verticalFraction * logicalSize.height,
    ),
  );
  return feature == null ? null : _toWireModel(feature);
}

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

    // The stable route identity: the route's declared name (our routes are
    // enum values, so the name survives path refactors). Screen attribution
    // binds to it; the path is the instance context.
    String? currentRouteName() {
      final configuration = delegate.currentConfiguration;
      return configuration.isEmpty ? null : configuration.last.route.name;
    }

    _host = StudioBridgeHost.attach(
      manifest: appStudioManifest,
      delegate: this,
      currentPath: currentPath,
      currentSession: () => ref.read(studioSessionStateProvider),
      // The connect snapshot carries the current screen's features so a
      // freshly connected Studio sees them without waiting for navigation.
      currentFeatures: _mountedFeatureInfos,
      currentLocale: () => ref.read(appLocaleProvider).languageCode,
      // Accept only a Studio that presents this project's secret. The build
      // bakes only the secret's HASH (STUDIO_KEY_HASH); the secret stays in
      // Studio. Empty define = local dev, no check.
      validateAccessKey: studioHashAccessValidator(
        const String.fromEnvironment('STUDIO_KEY_HASH'),
      ),
      inspectPoint: _featureAtPoint,
    );
    if (_host == null) return;

    // Features are discovered from mounted DwFeature widgets. A route change
    // may mount the new screen a frame or two later (and its content can load
    // asynchronously), so re-scan over a short window until it settles.
    void reportFeaturesSoon() {
      const rescanDelays = [
        Duration(milliseconds: 50),
        Duration(milliseconds: 400),
        Duration(milliseconds: 1000),
      ];
      for (final (index, delay) in rescanDelays.indexed) {
        final isLastRescan = index == rescanDelays.length - 1;
        Future<void>.delayed(delay, () {
          if (!mounted) return;
          final features = _mountedFeatureInfos();
          // An early re-scan often lands between screens — the old one already
          // parked under the new one, the new one not mounted yet — and finds
          // nothing. That is "the screen is not ready", not "the screen has no
          // features", and reporting it would flash an empty passport in
          // Studio, which takes these reports at face value. Only the last
          // re-scan is allowed to report emptiness, where it is real.
          if (features.isEmpty && !isLastRescan) return;
          _host?.reportFeatures(currentPath(), features);
        });
      }
    }

    void onRouteChanged() {
      _host?.reportRoute(currentPath(), routeName: currentRouteName());
      reportFeaturesSoon();
    }

    delegate.addListener(onRouteChanged);
    _removeRouteListener = () => delegate.removeListener(onRouteChanged);

    ref.listenManual(studioSessionStateProvider, (previous, next) {
      _host?.reportSession(next);
      reportFeaturesSoon();
    });

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
  Future<void> onSignInRequest(String identifier, String secret) => ref
      .read(studioPersonaSwitcherProvider.notifier)
      .signInWith(identifier: identifier, verificationCode: secret);

  @override
  Future<void> onSignOutRequest() =>
      ref.read(studioPersonaSwitcherProvider.notifier).signOutCurrentUser();

  @override
  void onLocaleRequest(String locale) =>
      ref.read(appLocaleProvider.notifier).selectLanguageCode(locale);

  @override
  Widget build(BuildContext context) => widget.child;
}
