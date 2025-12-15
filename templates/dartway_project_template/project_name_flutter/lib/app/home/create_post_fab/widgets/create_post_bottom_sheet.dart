import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

class CreatePostBottomSheet extends HookConsumerWidget {
  const CreatePostBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watchUserProfile;

    // Form controllers
    final titleController = useTextEditingController();
    final textController = useTextEditingController();

    // Track if form has changes
    final hasChanges = useState<bool>(false);

    // Track form validity
    final isFormValid = useState<bool>(false);

    // Update form state when text changes
    useEffect(() {
      void updateFormState() {
        final hasTitle = titleController.text.trim().isNotEmpty;
        final hasText = textController.text.trim().isNotEmpty;
        final hasAnyContent = hasTitle || hasText;

        hasChanges.value = hasAnyContent;
        isFormValid.value = hasTitle && hasText;
      }

      titleController.addListener(updateFormState);
      textController.addListener(updateFormState);

      return () {
        titleController.removeListener(updateFormState);
        textController.removeListener(updateFormState);
      };
    }, []);

    // Create post function
    Future<void> createPost() async {
      if (!isFormValid.value) return;

      try {
        final newPost = FeedPost(
          authorProfileId: userProfile.id!,
          title: titleController.text.trim(),
          text: textController.text.trim(),
          createdAt: DateTime.now(),
        );

        await ref.saveModel(newPost);

        // Clear form
        titleController.clear();
        textController.clear();
        hasChanges.value = false;
        isFormValid.value = false;

        // Close bottom sheet
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Error handling is done by DwCallback
        rethrow;
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),

          // Title
          const DwText('Create New Post', textStyle: AppText.title),
          const Gap(24),

          // Title field
          AppTextFormField(
            value: titleController.text,
            onChanged: (value) => titleController.text = value,
            labelText: 'Title',
            hintText: 'What\'s on your mind?',
            maxLines: 1,
            maxLength: 200,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Title is required';
              }
              if (value.length > 200) {
                return 'Title must be 200 characters or less';
              }
              return null;
            },
          ),
          const Gap(16),

          // Text field
          AppTextFormField(
            value: textController.text,
            onChanged: (value) => textController.text = value,
            labelText: 'Content',
            hintText: 'Share your thoughts...',
            maxLines: 5,
            maxLength: 5000,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Content is required';
              }
              if (value.length > 5000) {
                return 'Content must be 5000 characters or less';
              }
              return null;
            },
          ),
          const Gap(24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: DwButton.secondary(
                  'Cancel',
                  dwCallback: DwUiAction.create(
                    () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: DwButton.primary(
                  'Post',
                  dwCallback: isFormValid.value
                      ? DwUiAction.create(
                          createPost,
                          onSuccessNotification: 'Post created successfully!',
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
