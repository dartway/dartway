import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dartway_starter_channel.dart';
import 'dartway_starter_refusal.dart';

part 'settings.dw.dart';

/// The setting keys the app has. A key outside this set is refused: settings
/// are configuration the app reads, not a free-form store. The app's typed
/// catalogue (`AppSettingKey`) is held to this set by a test.
abstract final class AppSettingKeys {
  /// The name the app shows for itself.
  static const String appName = 'appName';

  /// Whether a new visitor may create an account (`'true'`/`'false'`); the
  /// server refuses a sign-up with `signUpClosed` while it is off.
  static const String signUpEnabled = 'signUpEnabled';

  static const Set<String> all = {appName, signUpEnabled};
}

/// One app setting. Its key is its identity.
final class AppSetting extends DwDataObject with _$AppSetting {
  const AppSetting({required this.id, required this.value});

  /// The setting key.
  @override
  final String id;
  final String value;
}

/// Every stored setting, live for every signed-in member: an admin renames the
/// app and every open screen follows.
final class ListAppSettings extends DwListRequest<AppSetting>
    with _$ListAppSettings {
  const ListAppSettings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayStarterChannel.settings),
  ];
}

/// Sets one setting — its own row, so two admins editing different settings
/// cannot overwrite each other. Admins only.
final class SaveAppSetting extends DwActionCommand<AppSetting>
    with _$SaveAppSetting
    implements DwSelfValidating {
  const SaveAppSetting({required this.key, required this.value});

  final String key;
  final String value;

  @override
  List<DwCallRefusal> validate() => [
    if (!AppSettingKeys.all.contains(key))
      DwCallRefusal(DartwayStarterRefusal.settingKeyUnknown, field: 'key'),
  ];
}
