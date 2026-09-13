import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';

part 'people.dw.dart';

/// A club member's profile: the project's half of an account.
///
/// The framework owns the account and its identifiers; this row is what the
/// club knows about the person, and it exists from the moment the account does
/// (created in the same transaction, see `exampleAuth`).
@DwTable('user_profile')
final class UserProfile extends DwEntity with _$UserProfile {
  const UserProfile({
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

  @DwUnique()
  @DwReferences('dw_account', onDelete: DwOnDelete.cascade)
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
  /// the server: no view carries it.
  final String? testVerificationCode;

  static const table = UserProfileTable();
}
