import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// A visible but disabled feature slot — shows where the showcase is heading
/// (feedback, tasks) without pretending it works already.
class ShowcaseLockedSection extends StatelessWidget {
  const ShowcaseLockedSection({
    required this.title,
    required this.hint,
    super.key,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShowcaseChrome.chipColor,
        borderRadius: ShowcaseChrome.cardRadius,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: ShowcaseChrome.mutedColor,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShowcaseChrome.chipLabel),
                Text(hint, style: ShowcaseChrome.captionText),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ShowcaseChrome.panelColor,
              borderRadius: ShowcaseChrome.chipRadius,
            ),
            child: const Text('Soon', style: ShowcaseChrome.captionText),
          ),
        ],
      ),
    );
  }
}
