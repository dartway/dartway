part of '../router.dart';

/// Parameters of the admin zone's addresses.
///
/// An enum rather than a string written in two places: the name stands in the
/// path template and in the read on the screen, and the two drifting apart
/// gives an empty page without a single error.
enum AdminParams<T> with DwNavigationParamsMixin<T> {
  /// The profile id on a user card.
  profileId<int>(),
}
