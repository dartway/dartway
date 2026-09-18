import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'people.dw.dart';

/// A club member's profile: the project's half of an account.
///
/// The framework owns the account and its identifiers; this row is what the
/// club knows about the person, and it exists from the moment the account does
/// (created in the same transaction, see `ExampleAuth.config`).
@DwSqlTable(
  'user_profile',
  indexes: [
    DwTableIndex(['firstName']),
  ],
)
final class UserProfileRow extends DwTableRow with _$UserProfileRow {
  const UserProfileRow({
    this.id,
    this.accountId,
    required this.phone,
    required this.firstName,
    this.lastName,
    this.imageUrl,
    this.gender,
    this.role = UserRole.client,
    this.agreedForMarketing = false,
    required this.conditionsAcceptedAt,
    this.testVerificationCode,
    this.deletedAt,
  });

  @override
  final int? id;

  /// The account that signs in as this person; `null` once they deleted it.
  /// The row stays: posts, messages and complaints of a person who left keep
  /// an author, and it carries nothing of them any more (`deletedAt`).
  @DwUniqueColumn()
  @DwForeignKey('dw_account', onDelete: DwOnDelete.setNull)
  final int? accountId;

  final String phone;
  final String firstName;
  final String? lastName;
  final String? imageUrl;
  final UserGender? gender;
  final UserRole role;
  final bool agreedForMarketing;
  final DateTime conditionsAcceptedAt;

  /// A fixed sign-in code for store reviewers and demo personas. Never leaves
  /// the server: no data object carries it.
  final String? testVerificationCode;

  /// When the person deleted their account. Everything personal was cleared
  /// then; what is left is a tombstone other people's content points at.
  final DateTime? deletedAt;

  static const tableDef = UserProfileTable();
}

extension UserProfileRowOwner on UserProfileRow {
  /// The account this profile signs in with — of a person who is still here.
  ///
  /// Reading it is a claim: this profile has an owner. Everything that belongs
  /// to one person alone — their bookings, their own live channels — is gone
  /// or cancelled by the time the account is, so nothing that outlives them
  /// asks for it. A tombstone asked for its account is a bug, not a `null`.
  int get ownerAccountId =>
      accountId ?? (throw StateError('Profile $id has no account: deleted'));
}
