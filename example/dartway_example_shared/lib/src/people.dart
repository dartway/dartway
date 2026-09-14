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
  });

  /// The profile id.
  @override
  final int id;
  final String firstName;
  final String? lastName;
  final String? imageUrl;
}

/// A profile as its owner and the club's admins see it.
final class UserProfile extends DwDataObject with _$UserProfile {
  const UserProfile({
    required this.id,
    required this.accountId,
    required this.phone,
    required this.firstName,
    required this.role,
    required this.agreedForMarketing,
    this.lastName,
    this.imageUrl,
    this.gender,
  });

  /// The profile id.
  @override
  final int id;

  /// The account the profile belongs to — the key of its owner's channels.
  final int accountId;
  final String phone;
  final String firstName;
  final String? lastName;
  final String? imageUrl;
  final UserGender? gender;
  final UserRole role;
  final bool agreedForMarketing;
}

/// The signed-in member's own profile, live on their profile channel.
///
/// [accountId] must be the caller's own account: the server refuses any other
/// with `dw.forbidden` and reads the profile of the caller, never of the
/// field. The field exists because a live request names its channel by its
/// own fields, and this one lives on `profile:<account>`: a channel keyed by
/// "whoever is signed in" is not something a request can declare.
final class GetMyProfile extends DwSingleRequest<UserProfile>
    with _$GetMyProfile {
  const GetMyProfile({required this.accountId});

  final int accountId;

  @override
  List<DwLiveChannel> get channels => [
    DwLiveChannel(ExampleChannel.profile, accountId),
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
    this.imageUrl = const DwFieldPatch.keep(),
  });

  /// `null` keeps the name; a name cannot be cleared.
  final String? firstName;
  final DwFieldPatch<String> lastName;
  final DwFieldPatch<UserGender> gender;
  final DwFieldPatch<String> imageUrl;

  @override
  List<DwCallRefusal> validate() => [
    if (firstName case final name? when name.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.firstNameRequired, field: 'firstName'),
  ];
}
