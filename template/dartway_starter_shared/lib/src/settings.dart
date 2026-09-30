import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dartway_starter_channel.dart';
import 'dartway_starter_refusal.dart';

part 'settings.dw.dart';

/// The app's settings: one value, edited by admins, read live by every
/// signed-in member.
///
/// Every field has a default, and the default is the value while nobody has
/// saved one — the server stores only what differs from it
/// (`ctx.settings`), so a setting added here needs nothing but its field.
final class AppSettings extends DwDataObject with _$AppSettings {
  const AppSettings({
    this.appName = 'DartwayStarter',
    this.signUpEnabled = true,
  });

  /// There is one: its identity is fixed.
  @override
  String get id => 'app';

  /// The name the app shows for itself.
  final String appName;

  /// Whether a new visitor may create an account; the server refuses a
  /// sign-up with `signUpClosed` while it is off.
  final bool signUpEnabled;
}

/// The app's settings, live for every signed-in member: an admin renames the
/// app and every open screen follows.
final class GetAppSettings extends DwSingleRequest<AppSettings>
    with _$GetAppSettings {
  const GetAppSettings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayStarterChannel.settings),
  ];
}

/// Changes the settings it names and leaves the rest: two admins editing
/// different settings cannot overwrite each other. Admins only.
final class SaveAppSettings extends DwActionCommand<AppSettings>
    with _$SaveAppSettings
    implements DwSelfValidating {
  const SaveAppSettings({this.appName, this.signUpEnabled});

  final String? appName;
  final bool? signUpEnabled;

  @override
  List<DwCallRefusal> validate() => [
    if (appName case final name? when name.trim().isEmpty)
      DwCallRefusal(DartwayStarterRefusal.appNameRequired, field: 'appName'),
  ];
}
