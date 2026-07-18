import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dartway_core.dart';

/// Role helpers used by CRUD config access filters and validations.
extension DwSessionExtension on Session {
  Future<UserProfile?> get currentUserProfile => dw.currentUserProfile(this);

  Future<bool> get isAdmin async =>
      (await currentUserProfile)?.role == UserRole.admin;
}

/// Access filter for admin-only models (e.g. the users table): the admin sees
/// everything, everyone else sees nothing.
Future<Expression<dynamic>?> adminOnlyAccessFilter(Session session) async =>
    await session.isAdmin ? null : Constant.bool(false);
