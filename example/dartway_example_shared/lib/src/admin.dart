import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'people.dart';

part 'admin.dw.dart';

/// The numbers on the admin dashboard, counted by the server.
final class AdminCounters extends DwDataObject with _$AdminCounters {
  const AdminCounters({
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

final class GetAdminCounters extends DwSingleRequest<AdminCounters>
    with _$GetAdminCounters {
  const GetAdminCounters();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.admin),
  ];
}

/// One numbered page of the members table, by name. Admins only.
///
/// [search] narrows by name or phone and [role] by role; both are part of
/// the request, so every filter and page is its own live state.
///
/// Live by the kind's default: a profile on the page is replaced in place;
/// a new member — or any profile not on the page — reads the page again, so
/// the total and the paging stay true.
final class ListUserProfiles extends DwTableRequest<UserProfile>
    with _$ListUserProfiles {
  const ListUserProfiles({
    this.page = 1,
    this.pageSize = 10,
    this.search = '',
    this.role,
  }) : super(maxPageSize: 100);

  @override
  final int page;

  @override
  final int pageSize;

  final String search;
  final UserRole? role;

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.admin),
  ];

  /// The server's filter, on one profile: a row on the page that leaves it
  /// (a role changed under a role filter) makes the page read again instead
  /// of staying on it.
  @override
  bool matches(UserProfile item) {
    if (role != null && item.role != role) return false;
    final text = search.trim().toLowerCase();
    if (text.isEmpty) return true;
    return item.firstName.toLowerCase().contains(text) ||
        (item.lastName?.toLowerCase().contains(text) ?? false) ||
        item.phone.contains(text);
  }
}

/// Changes someone's role. Admins only.
final class ChangeRole extends DwActionCommand<UserProfile> with _$ChangeRole {
  const ChangeRole({required this.profileId, required this.role});

  final int profileId;
  final UserRole role;
}
