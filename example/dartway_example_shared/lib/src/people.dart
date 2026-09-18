import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';

part 'people.dw.dart';

enum UserRole { client, staff, admin }

enum UserGender { female, male }

/// A person as other members see them: the coach of a session, the author of
/// a post or a message. Nothing on it is private.
final class PersonCard extends DwDataObject with _$PersonCard {
  const PersonCard({
    required this.id,
    required this.firstName,
    this.lastName,
    this.imageUrl,
    this.isDeleted = false,
  });

  /// The profile id.
  @override
  final int id;
  final String firstName;
  final String? lastName;
  final String? imageUrl;

  /// The person deleted their account: the profile stays so that what they
  /// wrote keeps an author, and carries nothing of them. The screen shows
  /// them as a deleted member; [firstName] is empty.
  final bool isDeleted;
}

/// A profile as its owner and the club's admins see it.
final class UserProfile extends DwDataObject with _$UserProfile {
  const UserProfile({
    required this.id,
    this.accountId,
    required this.phone,
    required this.firstName,
    required this.role,
    required this.agreedForMarketing,
    this.lastName,
    this.imageUrl,
    this.gender,
    this.isDeleted = false,
  });

  /// The profile id.
  @override
  final int id;

  /// The account the profile belongs to — the key of its owner's channels;
  /// `null` for a profile whose owner deleted their account.
  final int? accountId;
  final String phone;
  final String firstName;
  final String? lastName;
  final String? imageUrl;
  final UserGender? gender;
  final UserRole role;
  final bool agreedForMarketing;

  /// See [PersonCard.isDeleted].
  final bool isDeleted;
}

/// The signed-in member's own profile, live on their own profile channel.
///
/// It names no account: the server reads the caller's profile, and the
/// channel is the caller's (`profile:<account>`, resolved by the client for
/// whoever is signed in). A profile published to someone else's channel — an
/// admin changing a member's role — never reaches it.
final class GetMyProfile extends DwSingleRequest<UserProfile>
    with _$GetMyProfile {
  const GetMyProfile();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(ExampleChannel.profile),
  ];
}

/// Edits the signed-in member's own profile. A field left as it is is kept;
/// a cleared one is cleared.
final class UpdateMyProfile extends DwActionCommand<UserProfile>
    with _$UpdateMyProfile
    implements DwSelfValidating {
  const UpdateMyProfile({
    this.firstName,
    this.lastName = const DwFieldPatch.keep(),
    this.gender = const DwFieldPatch.keep(),
  });

  /// `null` keeps the name; a name cannot be cleared.
  final String? firstName;
  final DwFieldPatch<String> lastName;
  final DwFieldPatch<UserGender> gender;

  @override
  List<DwCallRefusal> validate() => [
    if (firstName case final name? when name.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.firstNameRequired, field: 'firstName'),
  ];
}
