import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Publishes a post under the signed-in staff member's name. The author is not
/// sent: the server takes it from the connection. A refusal — not staff, an
/// empty field — is shown in the user's language and keeps the sheet open.
class CreateNewsPostSheet extends HookWidget {
  const CreateNewsPostSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = useState('');
    final text = useState('');
    final isFormValid =
        title.value.trim().isNotEmpty && text.value.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.title(l10n.newClubPost),
        const Gap(16),
        AppTextFormField(
          value: title.value,
          onChanged: (value) => title.value = value,
          labelText: l10n.postTitleLabel,
          hintText: l10n.postTitleHint,
          maxLength: 200,
        ),
        const Gap(16),
        AppTextFormField(
          value: text.value,
          onChanged: (value) => text.value = value,
          labelText: l10n.postContentLabel,
          hintText: l10n.postContentHint,
          maxLines: 5,
          maxLength: 5000,
        ),
        const Gap(24),
        AppButton.primary(
          l10n.publish,
          onTap: isFormValid
              ? dw.action(
                  (_) => dw.command(
                    PublishNews(
                      title: title.value.trim(),
                      text: text.value.trim(),
                    ),
                  ),
                  onSuccessNotification: l10n.postPublished,
                  followUpIfMountedAction: (context, _) =>
                      Navigator.of(context).pop(),
                )
              : null,
        ),
      ],
    );
  }
}
