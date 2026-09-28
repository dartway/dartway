import 'package:flutter/foundation.dart';

import '../model/dw_media_item.dart';

/// A snapshot of a `DwMediaSession`'s queue — what a next-item card reads.
@immutable
final class DwMediaQueueState {
  const DwMediaQueueState({
    required this.items,
    required this.currentIndex,
    this.showNextPreview = false,
    this.autoplayCountdown,
  });

  final List<DwMediaItem> items;
  final int currentIndex;

  DwMediaItem get current => items[currentIndex];

  bool get hasNext => currentIndex + 1 < items.length;
  DwMediaItem? get next => hasNext ? items[currentIndex + 1] : null;

  bool get hasPrevious => currentIndex > 0;
  DwMediaItem? get previous => hasPrevious ? items[currentIndex - 1] : null;

  /// The next item is coming up: `DwMediaConfig.nextPreview` is on and the
  /// current item is within `nextPreviewLeadTime` of its end, or an autoplay
  /// countdown runs.
  final bool showNextPreview;

  /// Time left before autoplay moves to the next item, while a countdown
  /// runs (`DwMediaConfig.autoplayCountdown`); `null` otherwise.
  final Duration? autoplayCountdown;

  DwMediaQueueState copyWith({
    int? currentIndex,
    bool? showNextPreview,
    Duration? Function()? autoplayCountdown,
  }) => DwMediaQueueState(
    items: items,
    currentIndex: currentIndex ?? this.currentIndex,
    showNextPreview: showNextPreview ?? this.showNextPreview,
    autoplayCountdown: autoplayCountdown == null
        ? this.autoplayCountdown
        : autoplayCountdown(),
  );
}
