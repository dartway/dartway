import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// The server validates the business rule (own attended booking, one review
/// per visit) in the SessionReview CRUD config — the sheet only collects input.
class ReviewBottomSheet extends HookConsumerWidget {
  const ReviewBottomSheet({required this.booking, super.key});

  final SessionBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rating = useState(5);
    final reviewText = useState('');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.title(l10n.reviewSheetTitle),
        const Gap(16),
        AppRatingStars(
          rating: rating.value,
          onRatingChanged: (value) => rating.value = value,
        ),
        const Gap(16),
        AppTextFormField(
          value: reviewText.value,
          onChanged: (value) => reviewText.value = value,
          labelText: l10n.reviewLabel,
          hintText: l10n.reviewHint,
          maxLines: 3,
        ),
        const Gap(24),
        AppButton.primary(
          l10n.submitReview,
          onTap: DwUiAction.create(
            (context) async {
              await DwRepository.saveModel(
                SessionReview(
                  bookingId: booking.id!,
                  rating: rating.value,
                  reviewText: reviewText.value.trim().isEmpty
                      ? null
                      : reviewText.value.trim(),
                  createdAt: DateTime.now(),
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            onSuccessNotification: l10n.thanksForFeedback,
          ),
        ),
      ],
    );
  }
}
