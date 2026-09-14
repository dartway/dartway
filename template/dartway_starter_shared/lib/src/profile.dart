import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dartway_starter_channel.dart';
import 'dartway_starter_refusal.dart';

part 'profile.dw.dart';

/// Access role: a member, or an administrator with the panel.
enum UserRole { user, admin }

enum UserGender { female, male }

/// A profile as its owner and the admins see it.
///
/// [phone] and [email] are the account's sign-in identifiers. The framework
/// keeps them (`DwAccountService`); the server reads them into this object, so
/// the app never holds a second copy that could disagree with what signs in.
final class UserProfile extends DwDataObject with _$UserProfile {
  const UserProfile({
    required this.id,
    required this.accountId,
    required this.firstName,
    required this.role,
    required this.joinedAt,
    this.lastName,
    this.gender,
    this.avatarUrl,
    this.phone,
    this.email,
    this.agreedForMarketing = false,
  });

  /// The profile id.
  @override
  final int id;

  /// The account the profile belongs to — the key of its owner's channels.
  final int accountId;

  /// Empty until the member names themselves: the app asks for it before
  /// anything else.
  final String firstName;
  final String? lastName;
  final UserGender? gender;

  /// The public URL of the profile photo.
  final String? avatarUrl;

  /// The phone the account signs in with, digits only (`79991234567`).
  final String? phone;

  /// The e-mail the account signs in with, lower-cased.
  final String? email;

  final UserRole role;

  /// News and offers, as chosen at sign-up.
  final bool agreedForMarketing;

  /// When the account was created.
  final DateTime joinedAt;

  bool get isAdmin => role == UserRole.admin;

  /// The name to show: first and last name, or the identifier while there is
  /// none.
  String get displayName => switch ('$firstName ${lastName ?? ''}'.trim()) {
    '' => phone ?? email ?? '',
    final name => name,
  };
}

/// The signed-in member's own profile, live on their own profile channel.
///
/// It names no account: the server reads the caller's profile, and the channel
/// is the caller's (`profile:<account>`, resolved by the client for whoever is
/// signed in). A profile published to someone else's channel — an admin
/// changing a member's role — never reaches it.
final class GetMyProfile extends DwSingleRequest<UserProfile>
    with _$GetMyProfile {
  const GetMyProfile();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(DartwayStarterChannel.profile),
  ];
}

/// Edits the signed-in member's own profile. A field left as it is is kept; a
/// cleared one is cleared.
final class UpdateMyProfile extends DwActionCommand<UserProfile>
    with _$UpdateMyProfile
    implements DwSelfValidating {
  const UpdateMyProfile({
    this.firstName,
    this.lastName = const DwFieldPatch.keep(),
    this.gender = const DwFieldPatch.keep(),
    this.avatarFileId = const DwFieldPatch.keep(),
  });

  /// `null` keeps the name; a name cannot be cleared.
  final String? firstName;
  final DwFieldPatch<String> lastName;
  final DwFieldPatch<UserGender> gender;

  /// A finished upload of `DartwayStarterUpload.avatar` by the caller, or a
  /// clear. The replaced photo is deleted from storage.
  final DwFieldPatch<int> avatarFileId;

  @override
  List<DwCallRefusal> validate() => [
    if (firstName case final name? when name.trim().isEmpty)
      DwCallRefusal(
        DartwayStarterRefusal.firstNameRequired,
        field: 'firstName',
      ),
  ];
}
