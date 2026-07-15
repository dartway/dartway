import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class CreateNewsPostSheet extends HookConsumerWidget {
  const CreateNewsPostSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  (context) async {
                    await DwRepository.saveModel(
                      NewsPost(
                        authorProfileId: ref.readUserProfile.id!,
                        title: title.value.trim(),
                        text: text.value.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  onSuccessNotification: l10n.postPublished,
                )
              : null,
        ),
      ],
    );
  }
}
