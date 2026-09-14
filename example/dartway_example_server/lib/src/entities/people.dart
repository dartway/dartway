import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'people.dw.dart';

/// A club member's profile: the project's half of an account.
///
/// The framework owns the account and its identifiers; this row is what the
/// club knows about the person, and it exists from the moment the account does
/// (created in the same transaction, see `exampleAuth`).
@DwSqlTable(
  'user_profile',
  indexes: [
    DwTableIndex(['firstName']),
  ],
)
final class UserProfileRow extends DwTableRow with _$UserProfileRow {
  const UserProfileRow({
    this.id,
    required this.accountId,
    required this.phone,
    required this.firstName,
    this.lastName,
    this.imageUrl,
    this.gender,
    this.role = UserRole.client,
    this.agreedForMarketing = false,
    required this.conditionsAcceptedAt,
    this.testVerificationCode,
  });

  @override
  final int? id;

  @DwUniqueColumn()
  @DwForeignKey('dw_account', onDelete: DwOnDelete.cascade)
  final int accountId;

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

  static const table = UserProfileTable();
}
