import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The start of the current local day; moves on at midnight.
///
/// The schedule is `ListUpcomingSessions(from: today)`, and a request is its
/// own cache key: a `from` computed from `DateTime.now()` in `build` would be
/// a different request on every rebuild — a new fetch and a new subscription
/// each time. The day changes once a day, and so does the request.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final timer = Timer(midnight.difference(now), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    return DateTime(now.year, now.month, now.day);
  }
}
