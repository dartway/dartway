import 'package:flutter/foundation.dart';

/// Whether a [DwMediaItem] plays through the video or the audio engine.
enum DwMediaKind { video, audio }

/// How a [DwMediaItem] finds its bytes.
///
/// [DwMediaSource.url] is a plain address. [DwMediaSource.resolve] is called
/// again on every load **and on every [DwMediaController.retry]** — the shape
/// that turns an expired signed link into a retry rather than a dead end: a
/// project wraps its own "ask the server for a fresh URL" call and the player
/// never needs to know the link expires.
@immutable
final class DwMediaSource {
  const DwMediaSource.url(String url) : _url = url, _resolveUri = null;

  const DwMediaSource.resolve(Future<Uri> Function() resolve)
    : _url = null,
      _resolveUri = resolve;

  final String? _url;
  final Future<Uri> Function()? _resolveUri;

  /// Resolves the URI to play — called once per load attempt, so a resolver
  /// backed by a signed link is asked again on every [DwMediaController.retry].
  Future<Uri> resolve() {
    final resolver = _resolveUri;
    if (resolver != null) return resolver();
    return Future.value(Uri.parse(_url!));
  }
}

/// One thing the player can play: a video or an audio track.
///
/// [id] is the one identity used for the session's queue, for
/// [DwMediaPositionStore] keys and for "is this the active item" — two
/// `DwMediaItem`s with the same [id] are the same item even when their
/// [title] or [source] object differs, which is why equality is defined on
/// [id] alone.
@immutable
final class DwMediaItem {
  const DwMediaItem({
    required this.id,
    required this.kind,
    required this.source,
    this.title,
    this.artworkUrl,
    this.extras = const {},
  });

  /// Stable across app runs — used for resume, for "is this the active item"
  /// and as the [DwMediaPositionStore] key.
  final String id;

  final DwMediaKind kind;
  final DwMediaSource source;

  /// The app's own text — the package never renders it (no look).
  final String? title;
  final String? artworkUrl;

  /// Whatever the project wants to carry alongside the item (a lesson id, a
  /// chapter number) without the package knowing what it means.
  final Map<String, Object?> extras;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DwMediaItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DwMediaItem($id, $kind)';
}
