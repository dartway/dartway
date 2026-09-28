import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart'
    show Alignment, RouteTransitionsBuilder, Size;

import '../resume/dw_media_position_store.dart';

/// When a controller saves the position it plays, and when it gives up on the
/// item entirely. `DwMediaConfig.resume: null` turns resume off altogether.
///
/// - Saved every [saveInterval] while playing, and on pause ([saveOnPause]),
///   on the app going to the background ([saveOnBackground]) and when the
///   controller is disposed ([saveOnDispose]).
/// - A position under [minimum] is never saved: restarting the first seconds
///   costs nothing, and a title only glanced at claims no resume point.
/// - Past [clearPastFraction] of the duration the saved position is cleared
///   instead of updated — the item is done, and a resume point a minute
///   before the end is worse than none.
@immutable
final class DwMediaResumePolicy {
  const DwMediaResumePolicy({
    this.saveInterval = const Duration(seconds: 5),
    this.minimum = const Duration(seconds: 5),
    this.clearPastFraction = 0.9,
    this.saveOnPause = true,
    this.saveOnBackground = true,
    this.saveOnDispose = true,
  }) : assert(
         clearPastFraction > 0 && clearPastFraction <= 1,
         'clearPastFraction must be in (0, 1]',
       );

  final Duration saveInterval;
  final Duration minimum;
  final double clearPastFraction;
  final bool saveOnPause;
  final bool saveOnBackground;
  final bool saveOnDispose;
}

/// Which edges a released mini-player settles on
/// (`DwMediaConfig.miniPlayerSnapEdges`).
enum DwMiniPlayerSnapEdges {
  /// The nearer of left and right; it stays where it was dropped vertically.
  horizontal,

  /// The nearest of all four.
  all,
}

/// What happens to a session when its page goes and there is no mini-player
/// to take it (`DwMediaConfig.onLeaveWithoutMiniPlayer`).
enum DwMediaLeaveAction {
  /// Pause it; opening the same item again comes back to it.
  pause,

  /// End it and release its engine.
  stop,

  /// Let it play on with no picture — for audio an app controls elsewhere.
  keepPlaying,
}

/// Every behaviour of `dartway_media_flutter`, with its default — the global
/// floor a project sets once on `DwMedia(config:)`. **Nothing in the package
/// is a fixed policy**: each field is overridden for one session with a
/// [DwMediaOpenOptions] passed to `DwMedia.open()`, so a lecture queue with
/// resume and a countdown can live next to a short-clip feed with neither.
///
/// `docs/3-flutter/media.md` has the table: every field, its default, what it
/// changes.
@immutable
final class DwMediaConfig {
  const DwMediaConfig({
    this.autoplayOnOpen = false,
    this.autoplayNext = false,
    this.autoplayCountdown = true,
    this.autoplayCountdownDuration = const Duration(seconds: 5),
    this.autoplayCountdownTick = const Duration(seconds: 1),
    this.nextPreview = false,
    this.nextPreviewLeadTime = const Duration(seconds: 10),
    this.completedThreshold = 0.9,
    this.reachedEndTolerance = const Duration(milliseconds: 500),
    this.progressInterval = const Duration(seconds: 1),
    this.resume = const DwMediaResumePolicy(),
    this.speeds = const [],
    this.defaultSpeed = 1.0,
    this.rememberSpeedAcrossItems = true,
    this.skipBack = const Duration(seconds: 10),
    this.skipForward = const Duration(seconds: 10),
    this.fullscreen = true,
    this.fullscreenOrientations = const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    this.exitOrientations = const [DeviceOrientation.portraitUp],
    this.autoEnterFullscreenOnPlay = false,
    this.keepFullscreenAcrossItems = true,
    this.fullscreenTransitionDuration = const Duration(milliseconds: 200),
    this.fullscreenTransitionBuilder,
    this.fallbackAspectRatio = 16 / 9,
    this.miniPlayer = true,
    this.miniPlayerInitialSize = const Size(160, 90),
    this.miniPlayerInitialAlignment = Alignment.bottomRight,
    this.miniPlayerMinScale = 0.75,
    this.miniPlayerMaxScale = 2.0,
    this.miniPlayerSnapToEdges = true,
    this.miniPlayerSnapEdges = DwMiniPlayerSnapEdges.horizontal,
    this.miniPlayerSnapThreshold = double.infinity,
    this.miniPlayerCloseStopsPlayback = true,
    this.onLeaveWithoutMiniPlayer = DwMediaLeaveAction.pause,
    this.pauseVideoInBackground = true,
    this.backgroundAudio = false,
    this.wakelockWhilePlaying = true,
    this.singleActiveItem = true,
    this.webMutedStart = true,
    this.rememberSound = true,
    this.autoRetryCount = 0,
    this.autoRetryDelay = const Duration(seconds: 3),
    this.controlsAutoHideDelay = const Duration(seconds: 3),
    this.positionStore,
  }) : assert(
         completedThreshold > 0 && completedThreshold <= 1,
         'completedThreshold must be in (0, 1]',
       ),
       assert(
         miniPlayerMinScale > 0 && miniPlayerMinScale <= miniPlayerMaxScale,
         'miniPlayerMinScale must be positive and not above miniPlayerMaxScale',
       ),
       assert(autoRetryCount >= 0, 'autoRetryCount must not be negative'),
       assert(fallbackAspectRatio > 0, 'fallbackAspectRatio must be positive'),
       assert(
         miniPlayerSnapThreshold >= 0,
         'miniPlayerSnapThreshold must not be negative',
       );

  /// `DwMedia.open()` starts playing the first item at once.
  final bool autoplayOnOpen;

  /// Reaching the end of an item moves the queue to the next one.
  final bool autoplayNext;

  /// With [autoplayNext]: the move waits [autoplayCountdownDuration] after
  /// the end, counting down in `DwMediaQueueState.autoplayCountdown`, and
  /// `DwMediaSession.cancelAutoplay()` stops it. Off, the move is immediate.
  final bool autoplayCountdown;

  /// How long the countdown lasts; the move comes exactly then.
  final Duration autoplayCountdownDuration;

  /// How often `DwMediaQueueState.autoplayCountdown` updates while the
  /// countdown runs — the display, not the moment of the move. Zero shows
  /// only the starting value.
  final Duration autoplayCountdownTick;

  /// The queue reports the next item as coming up
  /// (`DwMediaQueueState.showNextPreview`) [nextPreviewLeadTime] before the
  /// current one ends — independent of [autoplayNext].
  final bool nextPreview;
  final Duration nextPreviewLeadTime;

  /// Fraction of the duration at which `DwMediaCallbacks.onCompleted` fires.
  /// A seek past it counts: this is "watched enough", not "played to the end".
  final double completedThreshold;

  /// How close to the duration a tick of real playback counts as the end, on
  /// top of the engine's own end event. `Duration.zero` leaves only the
  /// engine's event. A seek never counts, whatever the tolerance.
  final Duration reachedEndTolerance;

  /// The shortest gap between two `DwMediaCallbacks.onProgress` calls.
  final Duration progressInterval;

  /// The resume policy, or `null` for no resume at all.
  final DwMediaResumePolicy? resume;

  /// Speeds the controls offer. Empty turns the speed control off.
  final List<double> speeds;

  /// The speed an item starts at, unless [rememberSpeedAcrossItems] carries
  /// another one over.
  final double defaultSpeed;

  /// The speed chosen for one item stays for the next one in the queue.
  final bool rememberSpeedAcrossItems;

  /// How far `DwMediaSession.skipBack` / `skipForward` move.
  final Duration skipBack;
  final Duration skipForward;

  /// Whether a session may go fullscreen at all.
  final bool fullscreen;

  /// Orientations allowed while fullscreen. Empty leaves them alone.
  final List<DeviceOrientation> fullscreenOrientations;

  /// Orientations set when fullscreen ends. Empty means every orientation —
  /// the platform's own default.
  final List<DeviceOrientation> exitOrientations;

  /// Playing a video enters fullscreen on its own.
  final bool autoEnterFullscreenOnPlay;

  /// The queue moving on while fullscreen stays fullscreen; off leaves it.
  final bool keepFullscreenAcrossItems;

  /// How long the fullscreen route takes to come and go.
  final Duration fullscreenTransitionDuration;

  /// How the fullscreen route comes and goes; `null` fades.
  final RouteTransitionsBuilder? fullscreenTransitionBuilder;

  /// The ratio `DwVideoSurface` keeps while a video does not report its own.
  final double fallbackAspectRatio;

  /// Whether `DwMediaSession.minimize()` hands the session to
  /// `DwMiniPlayerHost`. Off, minimize does nothing.
  final bool miniPlayer;

  final Size miniPlayerInitialSize;
  final Alignment miniPlayerInitialAlignment;

  /// Pinch bounds, as multiples of [miniPlayerInitialSize].
  final double miniPlayerMinScale;
  final double miniPlayerMaxScale;

  /// A released mini-player settles on an edge of the screen.
  final bool miniPlayerSnapToEdges;

  /// Which edges it settles on.
  final DwMiniPlayerSnapEdges miniPlayerSnapEdges;

  /// How close to an edge, in logical pixels, a released mini-player must be
  /// to settle on it; further away it stays where it was dropped. The
  /// default snaps from anywhere.
  final double miniPlayerSnapThreshold;

  /// Closing the mini-player ends the session. Off, it pauses and hides it:
  /// the session stays open, and opening the same item comes back to it.
  final bool miniPlayerCloseStopsPlayback;

  /// What `DwMediaSession.minimize()` does with [miniPlayer] off — the page
  /// is gone and nothing shows the session.
  final DwMediaLeaveAction onLeaveWithoutMiniPlayer;

  /// A playing video pauses when the app goes to the background.
  final bool pauseVideoInBackground;

  /// A playing audio item keeps playing in the background; off pauses it.
  /// Needs platform configuration too — `docs/3-flutter/media.md`.
  final bool backgroundAudio;

  /// The screen stays on while a video plays.
  final bool wakelockWhilePlaying;

  /// Playing one session pauses whichever other session was playing.
  final bool singleActiveItem;

  /// On the web a video starts muted — a browser refuses to start sound
  /// without a gesture — until the person turns the sound on.
  final bool webMutedStart;

  /// The person's last mute choice carries to every item opened after it,
  /// across sessions, for the life of the app.
  final bool rememberSound;

  /// How many times a failed load retries itself — re-resolving the source —
  /// before the controller shows `DwMediaPlayState.error`.
  final int autoRetryCount;
  final Duration autoRetryDelay;

  /// How long `DwMediaSession.controlsVisible` stays true while the item
  /// plays and nobody touches the controls. `Duration.zero` never hides them.
  final Duration controlsAutoHideDelay;

  /// Where resume positions live. `null` keeps them in memory for the life of
  /// the app; pass a store over `dw.plugins.prefs` or the project's own
  /// storage to resume across launches.
  final DwMediaPositionStore? positionStore;

  /// This config with [options] laid over it — what `DwMedia.open()` hands
  /// the session. A field left `null` in [options] keeps this config's value.
  DwMediaConfig merge(DwMediaOpenOptions? options) {
    if (options == null) return this;
    return DwMediaConfig(
      autoplayOnOpen: options.autoplayOnOpen ?? autoplayOnOpen,
      autoplayNext: options.autoplayNext ?? autoplayNext,
      autoplayCountdown: options.autoplayCountdown ?? autoplayCountdown,
      autoplayCountdownDuration:
          options.autoplayCountdownDuration ?? autoplayCountdownDuration,
      autoplayCountdownTick:
          options.autoplayCountdownTick ?? autoplayCountdownTick,
      nextPreview: options.nextPreview ?? nextPreview,
      nextPreviewLeadTime: options.nextPreviewLeadTime ?? nextPreviewLeadTime,
      completedThreshold: options.completedThreshold ?? completedThreshold,
      reachedEndTolerance: options.reachedEndTolerance ?? reachedEndTolerance,
      progressInterval: options.progressInterval ?? progressInterval,
      resume: options.withoutResume ? null : options.resume ?? resume,
      speeds: options.speeds ?? speeds,
      defaultSpeed: options.defaultSpeed ?? defaultSpeed,
      rememberSpeedAcrossItems:
          options.rememberSpeedAcrossItems ?? rememberSpeedAcrossItems,
      skipBack: options.skipBack ?? skipBack,
      skipForward: options.skipForward ?? skipForward,
      fullscreen: options.fullscreen ?? fullscreen,
      fullscreenOrientations:
          options.fullscreenOrientations ?? fullscreenOrientations,
      exitOrientations: options.exitOrientations ?? exitOrientations,
      autoEnterFullscreenOnPlay:
          options.autoEnterFullscreenOnPlay ?? autoEnterFullscreenOnPlay,
      keepFullscreenAcrossItems:
          options.keepFullscreenAcrossItems ?? keepFullscreenAcrossItems,
      fullscreenTransitionDuration:
          options.fullscreenTransitionDuration ?? fullscreenTransitionDuration,
      fullscreenTransitionBuilder:
          options.fullscreenTransitionBuilder ?? fullscreenTransitionBuilder,
      fallbackAspectRatio: options.fallbackAspectRatio ?? fallbackAspectRatio,
      miniPlayer: options.miniPlayer ?? miniPlayer,
      miniPlayerInitialSize:
          options.miniPlayerInitialSize ?? miniPlayerInitialSize,
      miniPlayerInitialAlignment:
          options.miniPlayerInitialAlignment ?? miniPlayerInitialAlignment,
      miniPlayerMinScale: options.miniPlayerMinScale ?? miniPlayerMinScale,
      miniPlayerMaxScale: options.miniPlayerMaxScale ?? miniPlayerMaxScale,
      miniPlayerSnapToEdges:
          options.miniPlayerSnapToEdges ?? miniPlayerSnapToEdges,
      miniPlayerSnapEdges: options.miniPlayerSnapEdges ?? miniPlayerSnapEdges,
      miniPlayerSnapThreshold:
          options.miniPlayerSnapThreshold ?? miniPlayerSnapThreshold,
      miniPlayerCloseStopsPlayback:
          options.miniPlayerCloseStopsPlayback ?? miniPlayerCloseStopsPlayback,
      onLeaveWithoutMiniPlayer:
          options.onLeaveWithoutMiniPlayer ?? onLeaveWithoutMiniPlayer,
      pauseVideoInBackground:
          options.pauseVideoInBackground ?? pauseVideoInBackground,
      backgroundAudio: options.backgroundAudio ?? backgroundAudio,
      wakelockWhilePlaying:
          options.wakelockWhilePlaying ?? wakelockWhilePlaying,
      singleActiveItem: options.singleActiveItem ?? singleActiveItem,
      webMutedStart: options.webMutedStart ?? webMutedStart,
      rememberSound: options.rememberSound ?? rememberSound,
      autoRetryCount: options.autoRetryCount ?? autoRetryCount,
      autoRetryDelay: options.autoRetryDelay ?? autoRetryDelay,
      controlsAutoHideDelay:
          options.controlsAutoHideDelay ?? controlsAutoHideDelay,
      positionStore: options.positionStore ?? positionStore,
    );
  }
}

/// A sparse override of [DwMediaConfig] for one `DwMedia.open()` — every
/// field left `null` keeps the plugin's value. The fields mean what the
/// [DwMediaConfig] fields of the same name mean.
@immutable
final class DwMediaOpenOptions {
  const DwMediaOpenOptions({
    this.autoplayOnOpen,
    this.autoplayNext,
    this.autoplayCountdown,
    this.autoplayCountdownDuration,
    this.autoplayCountdownTick,
    this.nextPreview,
    this.nextPreviewLeadTime,
    this.completedThreshold,
    this.reachedEndTolerance,
    this.progressInterval,
    this.resume,
    this.withoutResume = false,
    this.speeds,
    this.defaultSpeed,
    this.rememberSpeedAcrossItems,
    this.skipBack,
    this.skipForward,
    this.fullscreen,
    this.fullscreenOrientations,
    this.exitOrientations,
    this.autoEnterFullscreenOnPlay,
    this.keepFullscreenAcrossItems,
    this.fullscreenTransitionDuration,
    this.fullscreenTransitionBuilder,
    this.fallbackAspectRatio,
    this.miniPlayer,
    this.miniPlayerInitialSize,
    this.miniPlayerInitialAlignment,
    this.miniPlayerMinScale,
    this.miniPlayerMaxScale,
    this.miniPlayerSnapToEdges,
    this.miniPlayerSnapEdges,
    this.miniPlayerSnapThreshold,
    this.miniPlayerCloseStopsPlayback,
    this.onLeaveWithoutMiniPlayer,
    this.pauseVideoInBackground,
    this.backgroundAudio,
    this.wakelockWhilePlaying,
    this.singleActiveItem,
    this.webMutedStart,
    this.rememberSound,
    this.autoRetryCount,
    this.autoRetryDelay,
    this.controlsAutoHideDelay,
    this.positionStore,
  }) : assert(
         !withoutResume || resume == null,
         'withoutResume and resume contradict each other',
       );

  final bool? autoplayOnOpen;
  final bool? autoplayNext;
  final bool? autoplayCountdown;
  final Duration? autoplayCountdownDuration;
  final Duration? autoplayCountdownTick;
  final bool? nextPreview;
  final Duration? nextPreviewLeadTime;
  final double? completedThreshold;
  final Duration? reachedEndTolerance;
  final Duration? progressInterval;

  /// A resume policy of this session's own.
  final DwMediaResumePolicy? resume;

  /// No resume for this session — `resume: null` cannot say it, since `null`
  /// already means "keep the plugin's".
  final bool withoutResume;

  final List<double>? speeds;
  final double? defaultSpeed;
  final bool? rememberSpeedAcrossItems;
  final Duration? skipBack;
  final Duration? skipForward;
  final bool? fullscreen;
  final List<DeviceOrientation>? fullscreenOrientations;
  final List<DeviceOrientation>? exitOrientations;
  final bool? autoEnterFullscreenOnPlay;
  final bool? keepFullscreenAcrossItems;
  final Duration? fullscreenTransitionDuration;
  final RouteTransitionsBuilder? fullscreenTransitionBuilder;
  final double? fallbackAspectRatio;
  final bool? miniPlayer;
  final Size? miniPlayerInitialSize;
  final Alignment? miniPlayerInitialAlignment;
  final double? miniPlayerMinScale;
  final double? miniPlayerMaxScale;
  final bool? miniPlayerSnapToEdges;
  final DwMiniPlayerSnapEdges? miniPlayerSnapEdges;
  final double? miniPlayerSnapThreshold;
  final bool? miniPlayerCloseStopsPlayback;
  final DwMediaLeaveAction? onLeaveWithoutMiniPlayer;
  final bool? pauseVideoInBackground;
  final bool? backgroundAudio;
  final bool? wakelockWhilePlaying;
  final bool? singleActiveItem;
  final bool? webMutedStart;
  final bool? rememberSound;
  final int? autoRetryCount;
  final Duration? autoRetryDelay;
  final Duration? controlsAutoHideDelay;
  final DwMediaPositionStore? positionStore;
}
