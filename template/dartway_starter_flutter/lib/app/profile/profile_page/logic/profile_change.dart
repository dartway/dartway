import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// What the form would change in [profile], or `null` when nothing is
/// different. Only what changed is sent: an unchanged field is kept, and a
/// cleared one is cleared rather than being indistinguishable from leaving
/// it alone.
UpdateMyProfile? profileChangeOf(
  UserProfile profile, {
  required String firstName,
  required String lastName,
  required UserGender? gender,
}) {
  final trimmedFirst = firstName.trim();
  final trimmedLast = lastName.trim();
  final firstChanged = trimmedFirst != profile.firstName;
  final lastChanged = trimmedLast != (profile.lastName ?? '');
  final genderChanged = gender != profile.gender;
  if (!firstChanged && !lastChanged && !genderChanged) return null;
  return UpdateMyProfile(
    firstName: firstChanged ? trimmedFirst : null,
    lastName: switch (trimmedLast) {
      _ when !lastChanged => const DwFieldPatch.keep(),
      '' => const DwFieldPatch.clear(),
      final value => DwFieldPatch.set(value),
    },
    gender: switch (gender) {
      _ when !genderChanged => const DwFieldPatch.keep(),
      final UserGender value => DwFieldPatch.set(value),
      null => const DwFieldPatch.clear(),
    },
  );
}
