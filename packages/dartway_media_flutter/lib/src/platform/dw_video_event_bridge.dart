import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// The owned initialization zone binds the event stream without reading the
/// controller's testing-only player ID. Unowned streams remain untouched.
@internal
final class DwVideoEventBinding {
  DwVideoEventBinding({
    required this.onEvent,
    required this.onError,
    this.onRelease,
  });

  final void Function(VideoEvent) onEvent;
  final bool Function(Object, StackTrace) onError;
  final void Function()? onRelease;
  bool _active = true;
  bool _claimed = false;
  bool get active => _active;

  Future<void> initialize(Future<void> Function() initialize) {
    final current = VideoPlayerPlatform.instance;
    if (current is! _VideoEventBridge) {
      VideoPlayerPlatform.instance = _VideoEventBridge(current);
    }
    // The SDK's first platform getter runs synchronously inside initialize,
    // before its first await. No foreign controller can interleave it.
    return runZoned(initialize, zoneValues: {_bindingKey: this});
  }

  DwVideoEventBinding? claim() {
    if (!_active || _claimed) return null;
    _claimed = true;
    return this;
  }

  void release() {
    if (!active) return;
    _active = false;
    onRelease?.call();
  }
}

final Object _bindingKey = Object();

final class _VideoEventBridge extends VideoPlayerPlatform {
  _VideoEventBridge(this.delegate);
  final VideoPlayerPlatform delegate;
  final Map<int, DwVideoEventBinding> _bindings = {};
  bool _installationInit = true;

  @override
  Future<void> init() async {
    if (_installationInit) {
      _installationInit = false;
      // video_player_web's public init only disposes existing players.
      // Installing a transparent adapter is not a restart of that platform.
      return;
    }
    for (final binding in _bindings.values) {
      binding.release();
    }
    _bindings.clear();
    await delegate.init();
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final source = delegate.videoEventsFor(playerId);
    final binding = _bindings[playerId];
    if (binding == null) return source;
    return source.transform(
      StreamTransformer.fromHandlers(
        handleData: (event, sink) {
          if (binding.active) binding.onEvent(event);
          sink.add(event);
        },
        handleError: (Object error, StackTrace stack, sink) {
          if (!binding.active || !binding.onError(error, stack)) {
            sink.addError(error, stack);
          }
        },
      ),
    );
  }

  @override
  Future<void> dispose(int playerId) {
    _bindings.remove(playerId)?.release();
    return delegate.dispose(playerId);
  }

  Future<int?> _create(Future<int?> Function() create) async {
    // Claim before invoking the delegate: even synchronous callbacks from
    // create cannot pass this owned token to another controller.
    final binding = (Zone.current[_bindingKey] as DwVideoEventBinding?)
        ?.claim();
    final playerId = await create();
    if (playerId != null && binding != null && binding.active) {
      _bindings[playerId] = binding;
    }
    return playerId;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      _create(() => delegate.createWithOptions(options));
  @override
  Future<int?> create(DataSource source) => _create(
    () =>
        // Preserve the platform's existing legacy entry point unchanged.
        // ignore: deprecated_member_use
        delegate.create(source),
  );
  @override
  Future<void> setLooping(int playerId, bool looping) =>
      delegate.setLooping(playerId, looping);
  @override
  Future<void> play(int playerId) => delegate.play(playerId);
  @override
  Future<void> pause(int playerId) => delegate.pause(playerId);
  @override
  Future<void> setVolume(int playerId, double volume) =>
      delegate.setVolume(playerId, volume);
  @override
  Future<void> seekTo(int playerId, Duration position) =>
      delegate.seekTo(playerId, position);
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) =>
      delegate.setPlaybackSpeed(playerId, speed);
  @override
  Future<Duration> getPosition(int playerId) => delegate.getPosition(playerId);
  @override
  Widget buildView(int playerId) =>
      // ignore: deprecated_member_use
      delegate.buildView(playerId);
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      delegate.buildViewWithOptions(options);
  @override
  Future<void> setMixWithOthers(bool mix) => delegate.setMixWithOthers(mix);
  @override
  Future<void> setAllowBackgroundPlayback(bool allow) =>
      delegate.setAllowBackgroundPlayback(allow);
  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool prevents,
  ) => delegate.setPreventsDisplaySleepDuringVideoPlayback(playerId, prevents);
  @override
  Future<void> setWebOptions(int playerId, VideoPlayerWebOptions options) =>
      delegate.setWebOptions(playerId, options);
  @override
  Future<List<VideoAudioTrack>> getAudioTracks(int playerId) =>
      delegate.getAudioTracks(playerId);
  @override
  Future<void> selectAudioTrack(int playerId, String trackId) =>
      delegate.selectAudioTrack(playerId, trackId);
  @override
  bool isAudioTrackSupportAvailable() =>
      delegate.isAudioTrackSupportAvailable();
  @override
  Future<List<VideoTrack>> getVideoTracks(int playerId) =>
      delegate.getVideoTracks(playerId);
  @override
  Future<void> selectVideoTrack(int playerId, VideoTrack? track) =>
      delegate.selectVideoTrack(playerId, track);
  @override
  bool isVideoTrackSupportAvailable() =>
      delegate.isVideoTrackSupportAvailable();
}
