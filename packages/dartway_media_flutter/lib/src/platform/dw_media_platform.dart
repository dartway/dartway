import 'package:flutter/foundation.dart';

/// Overrides [dwMediaIsWeb] in a test — the web rules (`webMutedStart`) are
/// otherwise unreachable from a VM test. Reset it to `null` in `tearDown`.
@visibleForTesting
bool? debugDwMediaIsWebOverride;

/// Whether the web rules apply.
bool get dwMediaIsWeb => debugDwMediaIsWebOverride ?? kIsWeb;

/// Errors a browser raises for a race the player itself caused — a `seek`
/// or `pause` interrupted by the next one, an element already gone from the
/// page — which mean nothing to the person watching. Reporting them as
/// `DwMediaPlayState.error` would put a retry screen over a video that
/// plays fine.
bool dwMediaIsBenignError(Object error) {
  final text = error.toString();
  return text.contains('AbortError') ||
      text.contains('interrupted') ||
      text.contains('removed from the document');
}

/// The browser refusing to start playback without a gesture — the answer is
/// to stay paused until the person presses play, not an error screen.
bool dwMediaIsPlayRefusal(Object error) =>
    error.toString().contains('NotAllowedError');
