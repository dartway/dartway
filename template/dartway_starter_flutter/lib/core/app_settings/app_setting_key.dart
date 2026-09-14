import 'package:collection/collection.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// How a setting is edited in the admin panel.
///
/// The members are exactly the row widgets the panel has, which is why this
/// enum lives in the app and not in the framework: a project that adds a
/// colour setting adds a `colour` member and the row widget next to it.
enum AppSettingType { toggle, number, text }

/// Every setting this app has, with its key, its type and the value it falls
/// back to.
///
/// The catalogue is the enum itself: open this file and you see the whole
/// list. The contract holds the same set of keys (`AppSettingKeys.all`) and
/// the server refuses any other (`settingKeyUnknown`), so a key is added in
/// both places — a test holds them equal.
///
/// The type argument is what makes a read typed: `valueOf(appName)` returns a
/// `String` and `valueOf(signUpEnabled)` a `bool`, checked at compile time.
/// [type] is a separate question — it answers *how to edit this*, which only
/// the admin panel asks, and only at runtime.
enum AppSettingKey<T> {
  /// The name the app shows for itself.
  appName<String>(
    AppSettingKeys.appName,
    AppSettingType.text,
    defaultValue: 'DartwayStarter',
  ),

  /// Whether a new visitor may create an account. The server enforces it.
  signUpEnabled<bool>(
    AppSettingKeys.signUpEnabled,
    AppSettingType.toggle,
    defaultValue: true,
  );

  const AppSettingKey(this.key, this.type, {required this.defaultValue});

  /// The setting's key on the wire and in the database — `AppSetting.id`. A
  /// contract: renaming it orphans the value that is already stored.
  final String key;

  final AppSettingType type;

  /// Used while nothing is stored yet, and when the stored text cannot be read
  /// as [T]. A setting nobody has touched must not be able to break a screen,
  /// so there is no failure path here at all.
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

/// Typed reads over the stored settings a `ListAppSettings` answers with.
extension AppSettingsReader on List<AppSetting> {
  /// The value of [setting]: the stored one, or its default while nobody has
  /// saved it.
  T valueOf<T>(AppSettingKey<T> setting) =>
      setting.parse(firstWhereOrNull((row) => row.id == setting.key)?.value);
}
