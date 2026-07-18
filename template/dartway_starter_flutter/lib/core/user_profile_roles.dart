import 'package:dartway_starter_client/dartway_starter_client.dart';

/// Role helpers mirroring the server-side checks. The server enforces access in
/// the CRUD configs; these only shape the UI — hiding a tab is not protection.
extension UserProfileRoles on UserProfile {
  bool get isAdmin => role == UserRole.admin;
}
