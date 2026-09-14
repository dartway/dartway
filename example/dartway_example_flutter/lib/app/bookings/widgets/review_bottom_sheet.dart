import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Collects a review of an attended visit. The rules — the caller's own
/// attended booking, one review per visit, a rating from 1 to 5 — are the
/// server's; a refusal is shown in the user's language and keeps the sheet
/// open.
class ReviewBottomSheet extends HookWidget {
  const ReviewBottomSheet({required this.booking, super.key});

  final SessionBooking booking;

  @override
  Widget build(BuildContext context) {
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
          onTap: dw.action(
            (_) {
              final text = reviewText.value.trim();
              return dw.command(
                ReviewVisit(
                  bookingId: booking.id,
                  rating: rating.value,
                  text: text.isEmpty ? null : text,
                ),
              );
            },
            onSuccessNotification: l10n.thanksForFeedback,
            followUpIfMountedAction: (context, _) =>
                Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
