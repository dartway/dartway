import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dw_studio_features.dart';
import 'dw_studio_locale.dart';
import 'dw_studio_persona_switcher.dart';
import 'dw_studio_user.dart';

/// Connects the app to DartWay Studio when it runs embedded in the Studio
/// preview frame: attaches the bridge, reports route, screen features, session
/// and language, and executes what Studio asks for.
///
/// Renders [child] untouched and stays inert outside an iframe, so a
/// production build carries it at no cost and needs no flag to turn it off.
///
/// Mount it in `MaterialApp.builder` — outside the router subtree, so the route
/// is observed through the router delegate rather than a `GoRouterState` that
/// only exists below the router:
///
/// ```dart
/// builder: (context, child) => DwStudioBinding(
///   core: dw,
///   manifest: appStudioManifest,
///   router: ref.watch(appRouterProvider),
///   describeUser: (profile) =>
///       DwStudioUser(identifier: profile.phone, label: profile.firstName),
///   locale: DwStudioLocale(
///     provider: appLocaleProvider,
///     select: (code) =>
///         ref.read(appLocaleProvider.notifier).selectLanguageCode(code),
///   ),
///   child: child ?? const SizedBox.shrink(),
/// ),
/// ```
class DwStudioBinding<UserProfileClass extends SerializableModel>
    extends ConsumerStatefulWidget {
  const DwStudioBinding({
    super.key,
    required this.core,
    required this.manifest,
    required this.router,
    required this.describeUser,
    required this.child,
    this.locale,
    this.validateAccessToken,
    this.channel,
  });

  /// The app's core. Passed rather than reached ambiently so the profile type
  /// is inferred from it — that is what types [describeUser].
  final DwCore<ServerpodClientShared, UserProfileClass> core;

  /// What this app declares about itself: its zones and their screens.
  final StudioProjectManifest manifest;

  /// The app's router — the source of the current route and the target of
  /// Studio's navigation requests.
  final DwRouter<Listenable> router;

  /// Who is signed in, in the terms Studio needs. See [DwStudioUser].
  final DwStudioUser Function(UserProfileClass userProfile) describeUser;

  /// The app's language, if it has more than one. See [DwStudioLocale].
  final DwStudioLocale? locale;

  /// Decides whether a connecting Studio may drive this app, from the access
  /// token it presents. Until it says yes, the bridge answers nothing and
  /// executes nothing.
  ///
  /// Pass
  /// `studioSignedAccessValidator(const String.fromEnvironment('STUDIO_APP_ORIGIN'))`
  /// — a token signed by Studio and issued for this app's own address gets in,
  /// so a token taken from here is useless anywhere else. The key that checks
  /// the signature ships inside the bridge package; the build names nothing but
  /// where it answers, and an empty define means local development with no
  /// check. Left null, any Studio is accepted: right on a laptop, wide open in
  /// production.
  final Future<bool> Function(String accessToken)? validateAccessToken;

  /// The pipe to talk over. Defaults to the embedding window — the only thing
  /// an app ever wants — so this exists to drive the binding from a test,
  /// exactly as `StudioBridgeHost.attach` takes one for the same reason.
  final StudioMessageChannel? channel;

  final Widget child;

  @override
  ConsumerState<DwStudioBinding<UserProfileClass>> createState() =>
      _DwStudioBindingState<UserProfileClass>();
}

class _DwStudioBindingState<UserProfileClass extends SerializableModel>
    extends ConsumerState<DwStudioBinding<UserProfileClass>>
    implements StudioBridgeHostDelegate {
  StudioBridgeHost? _host;
  DwStudioPersonaSwitcher? _personaSwitcher;
  VoidCallback? _removeRouteListener;

  @override
  void initState() {
    super.initState();
    final delegate = widget.router.router.routerDelegate;
    _personaSwitcher = DwStudioPersonaSwitcher(widget.core, ref);

    _host = StudioBridgeHost.attach(
      manifest: widget.manifest,
      delegate: this,
      currentPath: _currentPath,
      currentSession: _currentSession,
      // The connect snapshot carries the current screen's features so a
      // freshly connected Studio sees them without waiting for navigation.
      currentFeatures: dwStudioMountedFeatures,
      currentLocale: _currentLocale,
      validateAccessToken: widget.validateAccessToken,
      inspectPoint: dwStudioFeatureAtPoint,
      channel: widget.channel,
    );
    if (_host == null) return;

    void onRouteChanged() {
      _host?.reportRoute(_currentPath(), routeName: _currentRouteName());
      _reportFeaturesSoon();
    }

    delegate.addListener(onRouteChanged);
    _removeRouteListener = () => delegate.removeListener(onRouteChanged);

    _personaSwitcher!.isBusy.addListener(_reportSession);
    ref.listenManual(widget.core.userProfileProvider, (_, _) {
      _reportSession();
      _reportFeaturesSoon();
    });

    final locale = widget.locale;
    if (locale != null) {
      ref.listenManual(
        locale.provider,
        (_, next) => _host?.reportLocale(next.languageCode),
      );
    }
  }

  @override
  void dispose() {
    _removeRouteListener?.call();
    _personaSwitcher?.isBusy.removeListener(_reportSession);
    _personaSwitcher?.dispose();
    _host?.detach();
    super.dispose();
  }

  String _currentPath() {
    final configuration =
        widget.router.router.routerDelegate.currentConfiguration;
    return configuration.isEmpty ? '/' : configuration.uri.path;
  }

  /// The stable route identity: the route's declared name. Routes are enum
  /// values, so the name survives a path refactor — screen attribution binds
  /// to it, while the path is the instance context.
  String? _currentRouteName() {
    final configuration =
        widget.router.router.routerDelegate.currentConfiguration;
    return configuration.isEmpty ? null : configuration.last.route.name;
  }

  String _currentLocale() {
    final locale = widget.locale;
    return locale == null ? '' : ref.read(locale.provider).languageCode;
  }

  StudioSessionState _currentSession() {
    final isBusy = _personaSwitcher?.isBusy.value ?? false;
    final userProfile = ref.read(widget.core.userProfileProvider);
    if (userProfile == null) {
      return StudioSessionState(isSignedIn: false, isBusy: isBusy);
    }
    final user = widget.describeUser(userProfile);
    return StudioSessionState(
      isSignedIn: true,
      userIdentifier: user.identifier,
      displayLabel: user.label,
      isBusy: isBusy,
    );
  }

  void _reportSession() => _host?.reportSession(_currentSession());

  /// Features are discovered from mounted `DwFeature` widgets. A route change
  /// may mount the new screen a frame or two later (and its content can load
  /// asynchronously), so re-scan over a short window until it settles.
  void _reportFeaturesSoon() {
    const rescanDelays = [
      Duration(milliseconds: 50),
      Duration(milliseconds: 400),
      Duration(milliseconds: 1000),
    ];
    for (final (index, delay) in rescanDelays.indexed) {
      final isLastRescan = index == rescanDelays.length - 1;
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        final features = dwStudioMountedFeatures();
        // An early re-scan often lands between screens — the old one already
        // parked under the new one, the new one not mounted yet — and finds
        // nothing. That is "the screen is not ready", not "the screen has no
        // features", and reporting it would flash an empty passport in Studio,
        // which takes these reports at face value. Only the last re-scan is
        // allowed to report emptiness, where it is real.
        if (features.isEmpty && !isLastRescan) return;
        _host?.reportFeatures(_currentPath(), features);
      });
    }
  }

  @override
  void onNavigateRequest(String path) => widget.router.router.go(path);

  @override
  Future<void> onSignInRequest(String identifier, String secret) async =>
      _personaSwitcher?.signInWith(
        identifier: identifier,
        verificationCode: secret,
      );

  @override
  Future<void> onSignOutRequest() async =>
      _personaSwitcher?.signOutCurrentUser();

  @override
  void onLocaleRequest(String locale) => widget.locale?.select(locale);

  @override
  Widget build(BuildContext context) => widget.child;
}
