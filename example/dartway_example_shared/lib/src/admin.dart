import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';
import 'people.dart';

part 'admin.dw.dart';

/// The numbers on the admin dashboard, counted by the server.
final class AdminCountersView extends DwDataObject with _$AdminCountersView {
  const AdminCountersView({
    required this.members,
    required this.upcomingSessions,
    required this.newsPosts,
  });

  /// A single object: its identity is fixed.
  @override
  String get id => 'admin-counters';

  final int members;
  final int upcomingSessions;
  final int newsPosts;
}

final class GetAdminCounters extends DwSingleRequest<AdminCountersView>
    with _$GetAdminCounters {
  const GetAdminCounters();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.admin)];
}

/// Every profile. Admin only.
final class ListProfiles extends DwListRequest<ProfileView> with _$ListProfiles {
  const ListProfiles();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.admin)];
}

/// Changes someone's role. Admin only.
final class ChangeRole extends DwCommand<ProfileView> with _$ChangeRole {
  const ChangeRole({required this.profileId, required this.role});

  final int profileId;
  final UserRole role;
}
