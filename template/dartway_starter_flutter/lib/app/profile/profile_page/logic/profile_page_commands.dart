import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:image_picker/image_picker.dart';

/// The commands the profile page sends.
abstract final class ProfilePageCommands {
  /// What the form would change in [profile], or `null` when nothing is
  /// different. Only what changed is sent: an unchanged field is kept, and a
  /// cleared one is cleared rather than being indistinguishable from leaving
  /// it alone.
  static UpdateMyProfile? changeOf(
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

  /// Saves [change], from [changeOf].
  static Future<DwCallResult<UserProfile>> save(UpdateMyProfile change) =>
      dw.command(change);

  /// Picks an image, uploads it through [uploader] straight to the storage —
  /// the bytes never pass through the app server — and puts the stored file
  /// on the profile. A dismissed picker is not a failure; a refused or failed
  /// upload is held by [uploader] for the page to show.
  static Future<DwCallResult<UserProfile>?> changePhoto(
    DwUploadNotifier uploader,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final file = await uploader.upload(
      DartwayStarterUpload.avatar,
      DwUploadSource.bytes(bytes),
      fileName: picked.name.isEmpty ? 'avatar' : picked.name,
      contentType: _contentTypeOf(picked),
    );
    if (file == null) return null;
    return dw.command(UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)));
  }

  /// Takes the photo off the profile.
  static Future<DwCallResult<UserProfile>> removePhoto() =>
      dw.command(const UpdateMyProfile(avatarFileId: DwFieldPatch.clear()));

  /// The picked image's type: what the picker says, else what the name says.
  /// A type the avatar purpose does not take is refused by the server, and the
  /// refusal is shown under the photo.
  static String _contentTypeOf(XFile file) {
    if (file.mimeType case final type? when type.isNotEmpty) return type;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
