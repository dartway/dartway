import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';

part 'settings.dw.dart';

/// The setting keys the club has. A key outside this set is refused:
/// settings are configuration the app reads, not a free-form store.
const Set<String> exampleSettingKeys = {
  'clubName',
  'bookingEnabled',
  'supportPhone',
};

/// One app setting. Its key is its identity.
final class AppSetting extends DwDataObject with _$AppSetting {
  const AppSetting({required this.id, required this.value});

  /// The setting key.
  @override
  final String id;
  final String value;
}

final class ListAppSettings extends DwListRequest<AppSetting>
    with _$ListAppSettings {
  const ListAppSettings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.settings),
  ];
}

/// Sets a setting. Admins only.
final class SaveAppSetting extends DwActionCommand<AppSetting>
    with _$SaveAppSetting
    implements DwSelfValidating {
  const SaveAppSetting({required this.key, required this.value});

  final String key;
  final String value;

  @override
  List<DwCallRefusal> validate() => [
    if (!exampleSettingKeys.contains(key))
      DwCallRefusal(ExampleRefusal.settingKeyUnknown, field: 'key'),
  ];
}
