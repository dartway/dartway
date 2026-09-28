import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Overrides [dwMediaIsWeb] in a test — the web rules are otherwise
/// unreachable from a VM test. Reset it to `null` in `tearDown`.
@visibleForTesting
bool? debugDwMediaIsWebOverride;

/// Whether the web rules apply.
bool get dwMediaIsWeb => debugDwMediaIsWebOverride ?? kIsWeb;

/// The `DOMException` name `video_player_web` carries as the code of a
/// `PlatformException`, or `null` off the web and for anything else.
String? _domExceptionName(Object error) =>
    dwMediaIsWeb && error is PlatformException ? error.code : null;

/// A browser aborting a media request the player itself superseded — a
/// `play()` interrupted by the `pause()` after it, a seek by the next seek.
/// It means nothing to the person watching; everywhere else, and for any
/// other error, a failure is a failure.
bool dwMediaIsBenignError(Object error) =>
    _domExceptionName(error) == 'AbortError';

/// A browser refusing to start playback without a gesture — the item stays
/// paused until the person presses play.
bool dwMediaIsPlayRefusal(Object error) =>
    _domExceptionName(error) == 'NotAllowedError';
