import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dartway_core.dart';

extension DwSessionExtension on Session {
  Future<UserProfile?> get currentUserProfile => dw.currentUserProfile(this);
}
