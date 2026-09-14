import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Where each staff chat stood when its screen was last left in this app
/// session — the cursor of the newest message it had loaded — by account and
/// chat channel.
///
/// The chat reopens around it: what was already there is on screen, what
/// came later waits below. Read once when the screen opens and written when
/// it closes, so nothing listens to it: a plain map, not a notifier.
final chatReadPositionsProvider = Provider<Map<(int, int), String>>(
  (ref) => {},
);
