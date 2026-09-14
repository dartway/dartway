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

/// How many members the club has, published when someone joins.
///
/// A numbered page never grows by an update — a new row may belong on any
/// page, and every later row moves — so the members table reads its page
/// again when this arrives, and only then.
final class MemberCount extends DwDataObject with _$MemberCount {
  const MemberCount({required this.count});

  @override
  String get id => 'member-count';

  final int count;
}

/// One numbered page of the members table, by name. Admins only.
///
/// [search] narrows by name or phone and [role] by role; both are part of
/// the request, so every filter and page is its own live state.
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

  /// A profile on the page is replaced in place (the kind's default); a
  /// changed member count reads the page again.
  @override
  bool acceptsItem(Object? item) =>
      item is MemberCount || super.acceptsItem(item);

  @override
  DwUpdateAction onUpdate(Object item) =>
      item is MemberCount ? DwUpdateAction.refetch : super.onUpdate(item);
}

/// Changes someone's role. Admins only.
final class ChangeRole extends DwActionCommand<UserProfile> with _$ChangeRole {
  const ChangeRole({required this.profileId, required this.role});

  final int profileId;
  final UserRole role;
}
