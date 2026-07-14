import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dartway_core.dart';

/// Role helpers used by CRUD config access filters and validations.
extension DwSessionExtension on Session {
  Future<UserProfile?> get currentUserProfile => dw.currentUserProfile(this);

  Future<bool> get isStaffMember async {
    final role = (await currentUserProfile)?.role;
    return role == UserRole.staff || role == UserRole.admin;
  }

  Future<bool> get isClubAdmin async =>
      (await currentUserProfile)?.role == UserRole.admin;
}

/// Access filter for staff-only models (e.g. the staff chat): staff and admin
/// see everything, clients see nothing.
Future<Expression<dynamic>?> staffOnlyAccessFilter(Session session) async =>
    await session.isStaffMember ? null : Constant.bool(false);

/// Access filter for admin-only models (e.g. the users table): the admin sees
/// everything, everyone else sees nothing.
Future<Expression<dynamic>?> adminOnlyAccessFilter(Session session) async =>
    await session.isClubAdmin ? null : Constant.bool(false);
