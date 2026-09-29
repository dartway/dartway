import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:image_picker/image_picker.dart';

/// The commands the profile page sends.
abstract final class ProfilePageCommands {
  /// Saves [change], from [profileChangeOf].
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
