import '../models/studio_project_manifest.dart';
import '../models/studio_session_state.dart';

/// Events the Studio client emits about the connected project.
sealed class StudioProjectEvent {
  const StudioProjectEvent();
}

/// The handshake completed: the app delivered its manifest along with the
/// current route and session. Re-emitted after every app reload.
class StudioProjectConnected extends StudioProjectEvent {
  const StudioProjectConnected({
    required this.manifest,
    required this.currentPath,
    required this.session,
  });

  final StudioProjectManifest manifest;
  final String currentPath;
  final StudioSessionState session;
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
