import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_example_shared/src/dartway_example_channel.dart';
import 'package:dartway_example_shared/src/dartway_example_refusal.dart';

part 'settings.dw.dart';

/// The club's settings: one value, edited by admins, read live by every
/// signed-in member. Every field has a default, which is the value while
/// nobody has saved one — the server stores only what differs from it.
final class ClubSettings extends DwDataObject with _$ClubSettings {
  const ClubSettings({
    this.clubName = 'DartWay Fitness',
    this.bookingEnabled = true,
    this.supportPhone,
  });

  /// There is one: its identity is fixed.
  @override
  String get id => 'club';

  /// The club's name.
  final String clubName;

  /// Whether the schedule is open for booking.
  final bool bookingEnabled;

  /// The phone members call when something goes wrong, or `null` for none.
  final String? supportPhone;
}

final class GetClubSettings extends DwSingleRequest<ClubSettings>
    with _$GetClubSettings {
  const GetClubSettings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayExampleChannel.settings),
  ];
}

/// Changes the settings it names and leaves the rest. Admins only.
final class SaveClubSettings extends DwActionCommand<ClubSettings>
    with _$SaveClubSettings
    implements DwSelfValidating {
  const SaveClubSettings({
    this.clubName,
    this.bookingEnabled,
    this.supportPhone = const DwFieldPatch.keep(),
  });

  final String? clubName;
  final bool? bookingEnabled;

  /// Nullable in the settings, so a patch: it can be cleared.
  final DwFieldPatch<String> supportPhone;

  @override
  List<DwCallRefusal> validate() => [
    if (clubName case final name? when name.trim().isEmpty)
      DwCallRefusal(DartwayExampleRefusal.clubNameRequired, field: 'clubName'),
  ];
}
