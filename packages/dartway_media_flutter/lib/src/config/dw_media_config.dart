import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show Alignment, Size;

import '../resume/dw_media_position_store.dart';

/// When a controller saves the position it plays, and when it gives up on the
/// item entirely.
///
/// - Saved every [saveInterval], and — when [saveOnLifecycleEvents] is on —
///   also on pause, on the app going to the background, and on dispose.
/// - A position under [minimum] is never saved — nothing is lost by
///   restarting the first few seconds, and it keeps a title that was only
///   glanced at from claiming a resume point.
/// - Once playback passes [clearPastFraction] of the duration the saved
///   position is cleared instead of updated — the item is done, and a stray
///   9-minutes-into-a-10-minute-video resume point would be worse than none.
@immutable
final class DwMediaResumePolicy {
  const DwMediaResumePolicy({
    this.saveInterval = const Duration(seconds: 5),
    this.minimum = const Duration(seconds: 5),
    this.clearPastFraction = 0.9,
    this.saveOnLifecycleEvents = true,
  }) : assert(
         clearPastFraction > 0 && clearPastFraction <= 1,
         'clearPastFraction must be in (0, 1]',
       );

  final Duration saveInterval;
  final Duration minimum;
  final double clearPastFraction;

  /// Whether pause, the app going to the background, and dispose each also
  /// save immediately, on top of the periodic [saveInterval] save.
  final bool saveOnLifecycleEvents;
}

/// Every capability of `dartway_media_flutter`, with its default — the global
/// floor a project sets once. **Nothing here is a fixed policy**: every field
/// can be overridden per session with a [DwMediaOpenOptions] passed to
/// `DwMedia.open()`, so one project can run a lecture queue with resume and a
/// countdown next to a short-clip feed with neither, off one shared default.
///
/// ```dart
/// dw = DwFlutterToolbox(
///   plugins: [DwMedia(config: DwMediaConfig(speeds: [1.0, 1.5, 2.0]))],
/// );
/// ```
@immutable
final class DwMediaConfig {
  const DwMediaConfig({
    this.autoplayOnOpen = false,
    this.autoplayNext = false,
    this.autoplayCountdown = true,
    this.autoplayCountdownDuration = const Duration(seconds: 5),
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
    this.miniPlayer = true,
    this.miniPlayerInitialSize = const Size(160, 90),
    this.miniPlayerInitialAlignment = Alignment.bottomRight,
    this.miniPlayerMinScale = 0.5,
    this.miniPlayerMaxScale = 1.5,
    this.miniPlayerSnapToEdges = true,
    this.miniPlayerCloseStopsPlayback = true,
    this.pauseVideoInBackground = true,
    this.backgroundAudio = false,
    this.wakelockWhilePlaying = true,
    this.singleActiveItem = true,
    this.webMutedStart = true,
    this.webRememberSoundChoice = true,
    this.autoRetryCount = 0,
    this.autoRetryDelay = const Duration(seconds: 3),
    this.controlsAutoHideDelay = const Duration(seconds: 3),
    this.positionStore,
  }) : assert(
         completedThreshold > 0 && completedThreshold <= 1,
         'completedThreshold must be in (0, 1]',
       );

  /// Whether `DwMedia.open()` starts playing the first item right away.
  final bool autoplayOnOpen;

  /// Whether reaching the end of an item advances the queue on its own.
  final bool autoplayNext;

  /// Whether the next-item preview shows a counting-down number before
  /// autoplay fires. Ignored unless [autoplayNext] is also on.
  final bool autoplayCountdown;
  final Duration autoplayCountdownDuration;

  /// Whether the queue reports "next item is coming up" ahead of time —
  /// independent of [autoplayNext]: a project can preview without advancing.
  final bool nextPreview;

  /// How long before the end of the current item the next-item preview
  /// becomes visible. Ignored unless [nextPreview] is on.
  final Duration nextPreviewLeadTime;

  /// Fraction of the duration at which `DwMediaCallbacks.onCompleted` fires.
  final double completedThreshold;

  /// How close to the duration counts as "reached the end" for a genuinely
  /// still-playing item, on top of each engine's own real end-of-playback
  /// event. `Duration.zero` disables the extra leniency — only the engine's
  /// own event fires `onReachedEnd`. Never applied while a [seek]/[skip] is in
  /// flight, so a scrub to the end still never counts (see
  /// `DwMediaController.retry` docs).
  final Duration reachedEndTolerance;

  /// How often `DwMediaCallbacks.onProgress` may fire.
  final Duration progressInterval;

  /// Resume policy, or `null` to turn resume off entirely.
  final DwMediaResumePolicy? resume;

  /// Speeds a controls widget may offer via `DwMediaController.setSpeed`.
  /// Empty — the default — turns the capability off.
  final List<double> speeds;

  /// The speed a freshly opened item starts at, before
  /// [rememberSpeedAcrossItems] or an explicit `setSpeed` change it.
  final double defaultSpeed;

  /// Whether the speed chosen for one item carries over to the next one the
  /// queue advances to. When off, every item starts at [defaultSpeed].
  final bool rememberSpeedAcrossItems;

  /// How far `DwMediaSession.skipBack`/`skipForward` move, separately for
  /// each direction.
  final Duration skipBack;
  final Duration skipForward;

  /// Whether `DwMediaSession.enterFullscreen`/a mini-player expand may push
  /// the package's fullscreen route at all.
  final bool fullscreen;

  /// Orientations the fullscreen route allows while it is open. Empty leaves
  /// the platform's own default.
  final List<DeviceOrientation> fullscreenOrientations;

  /// Orientations restored on leaving fullscreen. Empty leaves whatever the
  /// app had set before entering untouched.
  final List<DeviceOrientation> exitOrientations;

  /// Whether starting playback enters fullscreen on its own (video only).
  final bool autoEnterFullscreenOnPlay;

  /// Whether the queue advancing while fullscreen keeps fullscreen open —
  /// off exits fullscreen on every item change.
  final bool keepFullscreenAcrossItems;

  /// Whether a minimized session is offered to `DwMiniPlayerHost` — off means
  /// closing the player page ends the session instead of shrinking it.
  final bool miniPlayer;

  final Size miniPlayerInitialSize;
  final Alignment miniPlayerInitialAlignment;
  final double miniPlayerMinScale;
  final double miniPlayerMaxScale;

  /// Whether dragging the mini-player snaps it to the nearest screen edge on
  /// release.
  final bool miniPlayerSnapToEdges;

  /// Whether closing the mini-player stops the session outright. Off pauses
  /// it instead, leaving it to be reopened where it left off.
  final bool miniPlayerCloseStopsPlayback;

  /// Whether video pauses when the app goes to the background. Audio's own
  /// background behaviour is [backgroundAudio].
  final bool pauseVideoInBackground;

  /// Whether an audio session keeps playing when the app goes to the
  /// background (see `docs/3-flutter/media.md` for the platform
  /// configuration this still needs).
  final bool backgroundAudio;

  /// Whether the screen is kept awake while a video plays.
  final bool wakelockWhilePlaying;

  /// Whether opening a session pauses whatever else is currently playing
  /// app-wide. Off allows several sessions to play at once.
  final bool singleActiveItem;

  /// Whether a web video starts muted (autoplay policies refuse an unmuted
  /// `play()` without a user gesture) and is unmuted once playback is
  /// actually granted.
  final bool webMutedStart;

  /// Whether the sound choice a person makes on the web (muted/unmuted)
  /// carries over to the next item in the same session.
  final bool webRememberSoundChoice;

  /// How many times a load failure retries itself before surfacing
  /// `DwMediaPlayState.error` and waiting for `DwMediaController.retry`.
  /// `0` — the default — means every failure is manual-retry only.
  final int autoRetryCount;
  final Duration autoRetryDelay;

  /// Published on the state a controls widget reads; the package renders no
  /// controls itself, so it never starts or cancels a hide timer — the
  /// project's own controls widget does, using this value.
  final Duration controlsAutoHideDelay;

  /// Where resume positions are kept. Defaults to a fresh
  /// [DwMediaInMemoryPositionStore] per `DwMedia` — pass one backed by
  /// persistent storage (`dw.plugins.prefs`, a project's own) to resume across
  /// launches.
  final DwMediaPositionStore? positionStore;

  /// Applies [options] on top of this config — `null` fields in [options]
  /// keep this config's value. What `DwMedia.open()` resolves per session.
  DwMediaConfig merge(DwMediaOpenOptions? options) {
    if (options == null) return this;
    return DwMediaConfig(
      autoplayOnOpen: options.autoplayOnOpen ?? autoplayOnOpen,
      autoplayNext: options.autoplayNext ?? autoplayNext,
      autoplayCountdown: options.autoplayCountdown ?? autoplayCountdown,
      autoplayCountdownDuration:
          options.autoplayCountdownDuration ?? autoplayCountdownDuration,
      nextPreview: options.nextPreview ?? nextPreview,
      nextPreviewLeadTime: options.nextPreviewLeadTime ?? nextPreviewLeadTime,
      completedThreshold: options.completedThreshold ?? completedThreshold,
      reachedEndTolerance:
          options.reachedEndTolerance ?? reachedEndTolerance,
      progressInterval: options.progressInterval ?? progressInterval,
      resume: options.hasResumeOverride ? options.resume : resume,
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
      miniPlayer: options.miniPlayer ?? miniPlayer,
      miniPlayerInitialSize:
          options.miniPlayerInitialSize ?? miniPlayerInitialSize,
      miniPlayerInitialAlignment:
          options.miniPlayerInitialAlignment ?? miniPlayerInitialAlignment,
      miniPlayerMinScale: options.miniPlayerMinScale ?? miniPlayerMinScale,
      miniPlayerMaxScale: options.miniPlayerMaxScale ?? miniPlayerMaxScale,
      miniPlayerSnapToEdges:
          options.miniPlayerSnapToEdges ?? miniPlayerSnapToEdges,
      miniPlayerCloseStopsPlayback:
          options.miniPlayerCloseStopsPlayback ??
          miniPlayerCloseStopsPlayback,
      pauseVideoInBackground:
          options.pauseVideoInBackground ?? pauseVideoInBackground,
      backgroundAudio: options.backgroundAudio ?? backgroundAudio,
      wakelockWhilePlaying:
          options.wakelockWhilePlaying ?? wakelockWhilePlaying,
      singleActiveItem: options.singleActiveItem ?? singleActiveItem,
      webMutedStart: options.webMutedStart ?? webMutedStart,
      webRememberSoundChoice:
          options.webRememberSoundChoice ?? webRememberSoundChoice,
      autoRetryCount: options.autoRetryCount ?? autoRetryCount,
      autoRetryDelay: options.autoRetryDelay ?? autoRetryDelay,
      controlsAutoHideDelay:
          options.controlsAutoHideDelay ?? controlsAutoHideDelay,
      positionStore: options.hasPositionStoreOverride
          ? options.positionStore
          : positionStore,
    );
  }
}

/// A sparse override of [DwMediaConfig] for one `DwMedia.open()` call — every
/// field left `null` falls back to the plugin's [DwMediaConfig]. See
/// [DwMediaConfig] for what each field does and its global default.
@immutable
final class DwMediaOpenOptions {
  const DwMediaOpenOptions({
    this.autoplayOnOpen,
    this.autoplayNext,
    this.autoplayCountdown,
    this.autoplayCountdownDuration,
    this.nextPreview,
    this.nextPreviewLeadTime,
    this.completedThreshold,
    this.reachedEndTolerance,
    this.progressInterval,
    Object? resume = _unset,
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
    this.miniPlayer,
    this.miniPlayerInitialSize,
    this.miniPlayerInitialAlignment,
    this.miniPlayerMinScale,
    this.miniPlayerMaxScale,
    this.miniPlayerSnapToEdges,
    this.miniPlayerCloseStopsPlayback,
    this.pauseVideoInBackground,
    this.backgroundAudio,
    this.wakelockWhilePlaying,
    this.singleActiveItem,
    this.webMutedStart,
    this.webRememberSoundChoice,
    this.autoRetryCount,
    this.autoRetryDelay,
    this.controlsAutoHideDelay,
    Object? positionStore = _unset,
  }) : _resume = resume,
       _positionStore = positionStore;

  final bool? autoplayOnOpen;
  final bool? autoplayNext;
  final bool? autoplayCountdown;
  final Duration? autoplayCountdownDuration;
  final bool? nextPreview;
  final Duration? nextPreviewLeadTime;
  final double? completedThreshold;
  final Duration? reachedEndTolerance;
  final Duration? progressInterval;

  // `resume` is itself nullable *as a value* (null = off), so telling "not
  // overridden" from "overridden to off" needs a second bit — the sentinel
  // below, same trick as `DwMediaPlaybackState.copyWith`.
  final Object? _resume;
  bool get hasResumeOverride => !identical(_resume, _unset);
  DwMediaResumePolicy? get resume => _resume as DwMediaResumePolicy?;

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
  final bool? miniPlayer;
  final Size? miniPlayerInitialSize;
  final Alignment? miniPlayerInitialAlignment;
  final double? miniPlayerMinScale;
  final double? miniPlayerMaxScale;
  final bool? miniPlayerSnapToEdges;
  final bool? miniPlayerCloseStopsPlayback;
  final bool? pauseVideoInBackground;
  final bool? backgroundAudio;
  final bool? wakelockWhilePlaying;
  final bool? singleActiveItem;
  final bool? webMutedStart;
  final bool? webRememberSoundChoice;
  final int? autoRetryCount;
  final Duration? autoRetryDelay;
  final Duration? controlsAutoHideDelay;

  final Object? _positionStore;
  bool get hasPositionStoreOverride => !identical(_positionStore, _unset);
  DwMediaPositionStore? get positionStore =>
      _positionStore as DwMediaPositionStore?;
}

const Object _unset = Object();
