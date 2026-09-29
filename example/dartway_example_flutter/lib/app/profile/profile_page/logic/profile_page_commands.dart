import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the profile page sends.
abstract final class ProfilePageCommands {
  /// What the form would change in [profile], or `null` when nothing is
  /// different. Only what changed is sent: an unchanged field is kept, and
  /// "not specified" clears the gender rather than being indistinguishable
  /// from leaving it alone.
  static UpdateMyProfile? changeOf(
    UserProfile profile, {
    required String firstName,
    required UserGender? gender,
  }) {
    final trimmedName = firstName.trim();
    final nameChanged = trimmedName != profile.firstName;
    final genderChanged = gender != profile.gender;
    if (!nameChanged && !genderChanged) return null;
    return UpdateMyProfile(
      firstName: nameChanged ? trimmedName : null,
      gender: switch (gender) {
        _ when !genderChanged => const DwFieldPatch.keep(),
        final UserGender value => DwFieldPatch.set(value),
        null => const DwFieldPatch.clear(),
      },
    );
  }

  /// Saves [change], from [changeOf].
  static Future<DwCallResult<UserProfile>> save(UpdateMyProfile change) =>
      dw.command(change);
}
