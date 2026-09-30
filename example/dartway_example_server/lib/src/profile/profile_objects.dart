import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Profile rows → the data objects clients see: the member's own profile, and
/// the card other people's screens show for them.
abstract final class ProfileObjects {
  static PersonCard person(UserProfileRow row) => PersonCard(
    id: row.id,
    firstName: row.firstName,
    lastName: row.lastName,
    imageUrl: row.imageUrl,
    isDeleted: row.deletedAt != null,
  );

  static UserProfile profile(UserProfileRow row) => UserProfile(
    id: row.id,
    accountId: row.accountId,
    phone: row.phone,
    firstName: row.firstName,
    lastName: row.lastName,
    imageUrl: row.imageUrl,
    gender: row.gender,
    role: row.role,
    agreedForMarketing: row.agreedForMarketing,
    isDeleted: row.deletedAt != null,
  );

  /// The rows of [ids] by id, in one query; `null` ids are skipped.
  static Future<Map<int, UserProfileRow>> rowsById(
    DwDatabaseHandle db,
    Iterable<int?> ids,
  ) async {
    final wanted = ids.whereType<int>().toSet();
    if (wanted.isEmpty) return const {};
    return {
      for (final row in await db.userProfiles.findByIds(wanted)) row.id: row,
    };
  }
}
