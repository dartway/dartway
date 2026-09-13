import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';

part 'people.dw.dart';

enum UserRole { client, staff, admin }

enum UserGender { female, male }

/// A person as others see them: a coach on a session, an author of a post.
final class PersonView extends DwDataObject with _$PersonView {
  const PersonView({
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

/// A profile as its owner and admins see it.
final class ProfileView extends DwDataObject with _$ProfileView {
  const ProfileView({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.role,
    required this.agreedForMarketing,
    this.lastName,
    this.imageUrl,
    this.gender,
  });

  @override
  final int id;
  final String phone;
  final String firstName;
  final String? lastName;
  final String? imageUrl;
  final UserGender? gender;
  final UserRole role;
  final bool agreedForMarketing;
}

/// The signed-in user's own profile.
///
/// [accountId] is the caller's own account: the server answers only for the
/// connection's account and refuses any other. It is a field anyway, so that
/// two accounts signed in one after the other on a device are two different
/// states — the cache cannot serve one person's profile to the next.
final class GetMyProfile extends DwMaybeRequest<ProfileView> with _$GetMyProfile {
  const GetMyProfile({required this.accountId});

  final int accountId;

  @override
  List<DwChannel> get channels => [DwChannel(ExampleChannel.profile, accountId)];

  @override
  bool matches(ProfileView object) => true;
}

/// Edits the signed-in user's own profile.
final class UpdateMyProfile extends DwCommand<ProfileView> with _$UpdateMyProfile {
  const UpdateMyProfile({
    this.firstName,
    this.lastName = const DwPatch.keep(),
    this.gender = const DwPatch.keep(),
    this.imageUrl = const DwPatch.keep(),
  });

  final String? firstName;
  final DwPatch<String> lastName;
  final DwPatch<UserGender> gender;
  final DwPatch<String> imageUrl;
}
