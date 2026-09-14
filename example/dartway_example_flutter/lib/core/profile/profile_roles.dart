import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Role helpers mirroring the server's access rules. The server enforces
/// access in its handlers and channel rules; these only shape the UI (e.g.
/// hide the staff chat tab).
extension ProfileRoles on UserProfile {
  bool get isStaffMember => role != UserRole.client;

  bool get isClubAdmin => role == UserRole.admin;
}
