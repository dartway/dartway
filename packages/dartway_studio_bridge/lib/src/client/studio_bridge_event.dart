import '../models/dw_feature_spec.dart';
import '../models/studio_project_manifest.dart';
import '../models/studio_session_state.dart';

/// Events the Studio client emits about the connected project.
sealed class StudioProjectEvent {
  const StudioProjectEvent();
}

/// The handshake completed: the app delivered its manifest along with the
/// current route, session and locale. Re-emitted after every app reload.
class StudioProjectConnected extends StudioProjectEvent {
  const StudioProjectConnected({
    required this.manifest,
    required this.currentPath,
    required this.session,
    this.features = const [],
    this.currentLocale = '',
  });

  final StudioProjectManifest manifest;
  final String currentPath;
  final StudioSessionState session;
  final List<DwFeatureSpec> features;

  /// Active UI locale, empty when the app is not localized.
  final String currentLocale;
}

/// The app's router moved to a new location.
class StudioProjectRouteChanged extends StudioProjectEvent {
  const StudioProjectRouteChanged(this.path);

  final String path;
}

/// The app's session changed (sign-in, sign-out, switch progress).
class StudioProjectSessionChanged extends StudioProjectEvent {
  const StudioProjectSessionChanged(this.session);

  final StudioSessionState session;
}

/// The features mounted on the current screen changed.
class StudioProjectFeaturesChanged extends StudioProjectEvent {
  const StudioProjectFeaturesChanged({
    required this.path,
    required this.features,
  });

  final String path;
  final List<DwFeatureSpec> features;
}

/// The app's UI locale changed.
class StudioProjectLocaleChanged extends StudioProjectEvent {
  const StudioProjectLocaleChanged(this.locale);

  final String locale;
}
