import 'package:flutter/foundation.dart';

import 'studio_message_drop.dart';

/// Hands one drop to a diagnostic [observer] without letting it take the
/// channel down: an observer is debugging code, and a channel that stopped
/// filtering messages because a log line threw would be a worse bug than the
/// one being chased. The error is not swallowed either — it goes to
/// [FlutterError.reportError], the path every other UI error in a DartWay app
/// takes.
///
/// Shared by both web channels so that "what happens when the observer throws"
/// has one answer instead of two.
void reportStudioMessageDrop(
  StudioMessageDropObserver? observer,
  StudioMessageDrop drop,
) {
  if (observer == null) return;
  try {
    observer(drop);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'dartway_studio_bridge',
        context: ErrorDescription('reporting a dropped Studio bridge message'),
      ),
    );
  }
}
