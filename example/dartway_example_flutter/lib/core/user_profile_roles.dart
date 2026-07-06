import 'package:dartway_example_client/dartway_example_client.dart';

/// Role helpers mirroring the server-side checks. The server enforces access
/// in CRUD configs; these only shape the UI (e.g. hide the staff chat tab).
extension UserProfileRoles on UserProfile {
  bool get isStaffMember => role == UserRole.staff || role == UserRole.admin;

  bool get isClubAdmin => role == UserRole.admin;
}
