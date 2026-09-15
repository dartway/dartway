/// A kind of notification. The project declares its categories as an enum in
/// its shared package — the server sends by them, and a settings screen may
/// show them:
///
/// ```dart
/// enum ExamplePushCategory with DwPushCategory { news, bookings }
/// ```
///
/// The framework stores the name and hands it to the project's eligibility
/// rule; what a category means — who opted out, which are quiet at night —
/// is the project's.
mixin DwPushCategory on Enum {
  /// The name stored with a message. Letters, digits, `_` and `.`.
  String get categoryName => name;
}
