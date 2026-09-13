import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';

part 'settings.dw.dart';

/// One app setting. Its key is its identity.
final class AppSettingView extends DwDataObject with _$AppSettingView {
  const AppSettingView({required this.id, required this.value});

  /// The setting key.
  @override
  final String id;
  final String value;
}

final class ListAppSettings extends DwListRequest<AppSettingView>
    with _$ListAppSettings {
  const ListAppSettings();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.settings)];
}

/// Sets a setting. Admin only; the key must be one the app declares.
final class SaveAppSetting extends DwCommand<AppSettingView>
    with _$SaveAppSetting {
  const SaveAppSetting({required this.key, required this.value});

  final String key;
  final String value;
}
