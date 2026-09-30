import 'package:dartway_starter_flutter/app/profile/profile_page/logic/profile_page_commands.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/refusal_text.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// The photo: tap, pick an image, and it goes to the profile
/// ([ProfilePageCommands.changePhoto]); the upload's progress and a refusal
/// show here.
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

    final busy = upload is DwUploadProgress;
    return Column(
      children: [
        DwActionBuilder(
          action: dw.action(
            (_) => ProfilePageCommands.changePhoto(uploader),
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
                  ? AppProgressIndicator(
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
        const Gap(AppSpace.s8),
        AppText.caption(switch (upload) {
          DwUploadError(:final refusal?) => l10n.refusalText(refusal),
          DwUploadError() => l10n.refusalUploadFailed,
          _ => l10n.profilePhotoHint,
        }, textAlign: TextAlign.center),
        if (avatarUrl != null)
          AppButton.text(
            l10n.profilePhotoRemove,
            onTap: dw.action(
              (_) => ProfilePageCommands.removePhoto(),
              onSuccessNotification: l10n.profilePhotoRemoved,
            ),
          ),
      ],
    );
  }
}
