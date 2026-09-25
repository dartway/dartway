import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

part 'profile_rows.dw.dart';

/// A member's profile: the project's half of an account.
///
/// The framework owns the account and its sign-in identifiers; this row is
/// what the app knows about the person, and it exists from the moment the
/// account does — created in the same transaction (`AppAuth.config`'s
/// `onAccountCreated`).
@DwSqlTable(
  'user_profile',
  indexes: [
    DwTableIndex(['createdAt']),
  ],
)
final class UserProfileRow extends DwTableRow with _$UserProfileRow {
  const UserProfileRow({
    this.id,
    required this.accountId,
    this.firstName = '',
    this.lastName,
    this.gender,
    this.avatarFileId,
    this.role = UserRole.user,
    this.agreedForMarketing = false,
    this.termsAcceptedAt,
    this.testVerificationCode,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwUniqueColumn()
  @DwForeignKey('dw_account', onDelete: DwOnDelete.cascade)
  final int accountId;

  final String firstName;
  final String? lastName;
  final UserGender? gender;

  /// The confirmed upload of the profile photo. A file deleted from under the
  /// profile leaves it without a photo rather than failing the delete.
  @DwForeignKey('dw_stored_file', onDelete: DwOnDelete.setNull)
  final int? avatarFileId;

  final UserRole role;
  final bool agreedForMarketing;

  /// When the terms were accepted — with the code that created the account.
  /// `null` for an account a tool made (the admin bootstrap, the dev seed),
  /// which accepted nothing on anyone's behalf.
  final DateTime? termsAcceptedAt;

  /// A fixed sign-in code — for a store reviewer, a demo persona, an
  /// end-to-end test — accepted instead of a delivered one. Never leaves the
  /// server: no data object carries it.
  final String? testVerificationCode;

  final DateTime createdAt;

  static const tableDef = UserProfileTable();
}
