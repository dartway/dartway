import 'package:dartway_core_shared/dartway_core_shared.dart';

/// Why the example server refuses. Codes only: the app renders every one of
/// them through its string catalogue.
enum ExampleRefusal with DwRefusalCodes {
  titleRequired,
  textRequired,
  durationNotPositive,
  priceNegative,
  capacityTooSmall,
  sessionInPast,
  sessionStarted,
  noSpotsLeft,
  alreadyBooked,
  bookingNotActive,
  ratingOutOfRange,
  reviewNeedsAttendance,
  alreadyReviewed,
  messageEmpty,
  settingKeyUnknown,
  firstNameRequired,
}
