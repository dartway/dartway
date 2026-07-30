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
/// Before it, a setting was found by comparing `settingKey` to a string literal
/// at each read site — the key was duplicated, the value arrived as a `String`
/// whatever it meant, and a row missing from the database made every screen
/// invent its own fallback.
///
/// The type argument is what makes a read typed: `settings.valueOf(appName)`
/// returns a `String` and `valueOf(signUpEnabled)` a `bool`, checked at compile
/// time. [type] is a separate question — it answers *how to edit this*, which
/// only the admin panel asks, and only at runtime.
enum AppSettingKey<T> {
  /// Shown in the app bar and on the greeting screen.
  appName<String>('appName', AppSettingType.text, defaultValue: 'DartWay'),

  /// Whether a new visitor may create an account.
  signUpEnabled<bool>(
    'signUpEnabled',
    AppSettingType.toggle,
    defaultValue: true,
  );

  const AppSettingKey(this.key, this.type, {required this.defaultValue});

  /// Storage key — the `AppSetting.settingKey` of the row holding this value.
  /// A contract: renaming it orphans the row that is already in the database.
  final String key;

  final AppSettingType type;

  /// Used when no row exists yet, and when the stored text cannot be read as
  /// [T]. A setting nobody has touched must not be able to break a screen, so
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

  /// Serialises a value back into the single text column.
  String format(T value) => value.toString();

  /// Accepts what a checkbox, a config file and a hand edit each tend to write.
  static bool? _parseBool(String value) => switch (value.toLowerCase()) {
    'true' || '1' || 'yes' => true,
    'false' || '0' || 'no' => false,
    _ => null,
  };
}
