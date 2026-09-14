import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dartway_starter_channel.dart';
import 'profile.dart';

part 'admin.dw.dart';

/// The numbers on the admin dashboard, counted by the server and republished
/// by every command that changes them — a dashboard never reads again on its
/// own.
final class AdminCounters extends DwDataObject with _$AdminCounters {
  const AdminCounters({
    required this.members,
    required this.admins,
    required this.marketingOptIns,
  });

  /// A single object: its identity is fixed.
  @override
  String get id => 'admin-counters';

  /// Every account with a profile.
  final int members;

  /// Of them, administrators.
  final int admins;

  /// Of them, those who agreed to news and offers.
  final int marketingOptIns;
}

final class GetAdminCounters extends DwSingleRequest<AdminCounters>
    with _$GetAdminCounters {
  const GetAdminCounters();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayStarterChannel.admin),
  ];
}

/// One numbered page of the members table, newest first. Admins only.
///
/// [search] narrows by name, phone or e-mail and [role] by role; both are part
/// of the request, so every filter and page is its own live state. A profile
/// on the page is replaced in place; a new member — or any profile not on the
/// page — reads the page again, so the total and the paging stay true.
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
    DwLiveChannel(DartwayStarterChannel.admin),
  ];

  /// The server's filter, on one profile: a row on the page that leaves it (a
  /// role changed under a role filter) makes the page read again instead of
  /// staying on it.
  @override
  bool matches(UserProfile item) {
    if (role != null && item.role != role) return false;
    final text = search.trim().toLowerCase();
    if (text.isEmpty) return true;
    return [
      item.firstName,
      ?item.lastName,
      ?item.phone,
      ?item.email,
    ].any((value) => value.toLowerCase().contains(text));
  }
}

/// One sign-in identifier of an account, as the admin's user card lists it.
final class UserIdentifier extends DwDataObject with _$UserIdentifier {
  const UserIdentifier({
    required this.id,
    required this.kind,
    required this.value,
    required this.addedAt,
    this.verifiedAt,
  });

  /// The identity id.
  @override
  final int id;

  final DwIdentifierKind kind;
  final String value;

  /// When it was attached to the account.
  final DateTime addedAt;

  /// When a code sent to it was last confirmed; `null` for an identifier a
  /// tool attached (the admin bootstrap, the dev seed) that never signed in.
  final DateTime? verifiedAt;
}

/// What the admin's user card shows about an account: the profile, every
/// identifier it signs in with, and when its terms were accepted.
final class UserCard extends DwDataObject with _$UserCard {
  const UserCard({
    required this.id,
    required this.profile,
    this.identifiers = const [],
    this.termsAcceptedAt,
  });

  /// The profile id.
  @override
  final int id;

  final UserProfile profile;

  /// Oldest first.
  final List<UserIdentifier> identifiers;

  /// When the terms were accepted at sign-up; `null` for an account a tool
  /// made, which accepted nothing.
  final DateTime? termsAcceptedAt;
}

/// The user card of [profileId], live: a role changed, a profile edited or an
/// identifier changed — here, by another admin or by the member — updates it.
/// Admins only.
final class GetUserCard extends DwSingleRequest<UserCard> with _$GetUserCard {
  const GetUserCard({required this.profileId});

  final int profileId;

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayStarterChannel.admin),
  ];
}

/// Changes someone's role. Admins only, and never an admin's own
/// (`ownRoleLocked`).
final class ChangeUserRole extends DwActionCommand<UserProfile>
    with _$ChangeUserRole {
  const ChangeUserRole({required this.profileId, required this.role});

  final int profileId;
  final UserRole role;
}
