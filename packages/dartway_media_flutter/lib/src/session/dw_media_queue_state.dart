import 'package:flutter/foundation.dart';

import '../model/dw_media_item.dart';

/// A snapshot of `DwMediaSession`'s queue — what a next-item preview card
/// reads to draw itself.
@immutable
final class DwMediaQueueState {
  const DwMediaQueueState({
    required this.items,
    required this.currentIndex,
    this.showNextPreview = false,
    this.autoplayCountdownSeconds,
  });

  final List<DwMediaItem> items;
  final int currentIndex;

  DwMediaItem get current => items[currentIndex];

  bool get hasNext => currentIndex + 1 < items.length;
  DwMediaItem? get next => hasNext ? items[currentIndex + 1] : null;

  bool get hasPrevious => currentIndex > 0;
  DwMediaItem? get previous => hasPrevious ? items[currentIndex - 1] : null;

  /// Whether the next-item card should be visible —
  /// `options.nextPreview` and within `options.nextPreviewLeadTime` of the
  /// end.
  final bool showNextPreview;

  /// Seconds left before autoplay advances the queue, or `null` when no
  /// countdown is running (`options.autoplayNext`/`autoplayCountdown` off, or
  /// not yet within the lead time).
  final int? autoplayCountdownSeconds;

  DwMediaQueueState copyWith({
    int? currentIndex,
    bool? showNextPreview,
    Object? autoplayCountdownSeconds = _unset,
  }) => DwMediaQueueState(
    items: items,
    currentIndex: currentIndex ?? this.currentIndex,
    showNextPreview: showNextPreview ?? this.showNextPreview,
    autoplayCountdownSeconds: identical(autoplayCountdownSeconds, _unset)
        ? this.autoplayCountdownSeconds
        : autoplayCountdownSeconds as int?,
  );
}

const Object _unset = Object();
