import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/refusal_text.dart';
import 'package:dartway_starter_flutter/shared/widgets/user_avatar.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

/// The photo: tap, pick an image, and it goes straight to the storage — the
/// bytes never pass through the app server — then the profile references the
/// stored file by id and shows its public URL.
class AvatarPicker extends HookWidget {
  const AvatarPicker({required this.avatarUrl, super.key});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // One upload slot for the screen: its progress, error and result.
    final uploader = useMemoized(dw.uploader);
    useEffect(() => uploader.dispose, [uploader]);
    final upload = useValueListenable(uploader);

    Future<DwCallResult<UserProfile>?> pickAndUpload() async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      // Dismissed: not a failure.
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      final file = await uploader.upload(
        DartwayStarterUpload.avatar,
        DwUploadSource.bytes(bytes),
        fileName: picked.name.isEmpty ? 'avatar' : picked.name,
        contentType: _contentTypeOf(picked),
      );
      // The uploader holds the refusal or the error; it is shown below.
      if (file == null) return null;
      return dw.command(
        UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)),
      );
    }

    final busy = upload is DwUploadProgress;
    return Column(
      children: [
        DwActionBuilder(
          action: dw.action(
            (_) => pickAndUpload(),
            customNotificationBuilder: (result) => result == null
                ? null
                : DwUiNotification.success(l10n.profilePhotoUpdated),
          ),
          builder: (context, onPressed, running) => InkResponse(
            onTap: busy ? null : onPressed,
            child: UserAvatar(
              avatarUrl: avatarUrl,
              radius: 48,
              placeholder: Icons.photo_camera_outlined,
              child: busy || running
                  ? CircularProgressIndicator(
                      value: switch (upload) {
                        DwUploadProgress(:final fraction) when fraction > 0 =>
                          fraction,
                        _ => null,
                      },
                    )
                  : null,
            ),
          ),
        ),
        const Gap(8),
        AppText.caption(switch (upload) {
          DwUploadError(:final refusal?) => l10n.refusalText(refusal),
          DwUploadError() => l10n.refusalUploadFailed,
          _ => l10n.profilePhotoHint,
        }, textAlign: TextAlign.center),
        if (avatarUrl != null)
          AppButton.text(
            l10n.profilePhotoRemove,
            onTap: dw.action(
              (_) => dw.command(
                const UpdateMyProfile(avatarFileId: DwFieldPatch.clear()),
              ),
              onSuccessNotification: l10n.profilePhotoRemoved,
            ),
          ),
      ],
    );
  }

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
