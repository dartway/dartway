import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class CreateNewsPostSheet extends HookConsumerWidget {
  const CreateNewsPostSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = useState('');
    final text = useState('');
    final isFormValid =
        title.value.trim().isNotEmpty && text.value.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.title('New club post'),
        const Gap(16),
        AppTextFormField(
          value: title.value,
          onChanged: (value) => title.value = value,
          labelText: 'Title',
          hintText: 'What is happening?',
          maxLength: 200,
        ),
        const Gap(16),
        AppTextFormField(
          value: text.value,
          onChanged: (value) => text.value = value,
          labelText: 'Content',
          hintText: 'Tell the members...',
          maxLines: 5,
          maxLength: 5000,
        ),
        const Gap(24),
        DwButton.primary(
          'Publish',
          dwCallback: isFormValid
              ? DwUiAction.create(
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
                  onSuccessNotification: 'Post published!',
                )
              : null,
        ),
      ],
    );
  }
}
