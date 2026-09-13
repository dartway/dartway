/// How a setting is edited in the admin panel.
///
/// The members are exactly the row widgets the kit has, which is why this enum
/// lives in the app and not in the framework: a project that adds a colour
/// setting adds a `colour` member and the row widget next to it.
enum AppSettingType { toggle, number, text }

/// Every setting this app has, with its storage key, its type and the value it
/// falls back to.
///
/// The catalogue is the enum itself: open this file and you see the whole list.
/// The server holds the same set of keys and refuses any other
/// (`settingKeyUnknown`), so a key is added in both places.
///
/// The type argument is what makes a read typed: `valueOf(clubName)` returns a
/// `String` and `valueOf(bookingEnabled)` a `bool`, checked at compile time.
/// [type] is a separate question — it answers *how to edit this*, which only
/// the admin panel asks, and only at runtime.
enum AppSettingKey<T> {
  /// The club's name.
  clubName<String>(
    'clubName',
    AppSettingType.text,
    defaultValue: 'DartWay Fitness',
  ),

  /// Whether the schedule is open for booking.
  bookingEnabled<bool>(
    'bookingEnabled',
    AppSettingType.toggle,
    defaultValue: true,
  ),

  /// The phone members call when something goes wrong.
  supportPhone<String>('supportPhone', AppSettingType.text, defaultValue: '');

  const AppSettingKey(this.key, this.type, {required this.defaultValue});

  /// The setting's key on the wire and in the database — `AppSettingView.id`.
  /// A contract: renaming it orphans the value that is already stored.
  final String key;

  final AppSettingType type;

  /// Used while nothing is stored yet, and when the stored text cannot be read
  /// as [T]. A setting nobody has touched must not be able to break a screen, so
  /// there is no failure path here at all.
  final T defaultValue;

  /// Reads the stored text as [T].
  ///
  /// Switching on [defaultValue] rather than on [T] is deliberate: `T` is gone
  /// at runtime, while the default value carries the same type and is always
  /// there.
  T parse(String? storedValue) {
    if (storedValue == null) return defaultValue;

    final trimmed = storedValue.trim();
    final parsed = switch (defaultValue) {
      bool _ => _parseBool(trimmed),
      int _ => int.tryParse(trimmed),
      double _ => double.tryParse(trimmed.replaceAll(',', '.')),
      String _ => trimmed,
      _ => null,
    };

    return parsed is T ? parsed : defaultValue;
  }

  /// Serialises a value back into the stored text.
  String format(T value) => value.toString();

  /// Accepts what a checkbox, a config file and a hand edit each tend to write.
  static bool? _parseBool(String value) => switch (value.toLowerCase()) {
    'true' || '1' || 'yes' => true,
    'false' || '0' || 'no' => false,
    _ => null,
  };
}
