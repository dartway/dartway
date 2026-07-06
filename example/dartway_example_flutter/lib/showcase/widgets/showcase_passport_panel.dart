import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_language_provider.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_location_provider.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_navigation_model.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_locked_section.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_passport_section.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// The screen passport: purpose, what the screen demonstrates, questions to
/// discuss — plus locked slots for the upcoming feedback and task queue.
class ShowcasePassportPanel extends ConsumerWidget {
  const ShowcasePassportPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = ref.watch(showcaseNavigationProvider).currentSpec;
    final language = ref.watch(showcaseLanguageStateProvider);
    final path = ref.watch(showcaseLocationProvider);

    return Container(
      width: ShowcaseChrome.panelWidth,
      color: ShowcaseChrome.panelColor,
      child: spec == null
          ? const Center(
              child: Text(
                'No passport for this screen yet',
                style: ShowcaseChrome.captionText,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  spec.title.resolve(language),
                  style: ShowcaseChrome.screenTitle,
                ),
                Text(path, style: ShowcaseChrome.captionText),
                const Gap(20),
                ShowcasePassportSection(
                  heading: 'Purpose',
                  body: spec.purpose.resolve(language),
                ),
                ShowcasePassportSection(
                  heading: 'What it demonstrates',
                  bullets: [
                    for (final feature in spec.featureSpec)
                      feature.resolve(language),
                  ],
                ),
                ShowcasePassportSection(
                  heading: 'Discuss',
                  numbered: true,
                  bullets: [
                    for (final question in spec.discussionQuestions)
                      question.resolve(language),
                  ],
                ),
                const ShowcaseLockedSection(
                  title: 'Feedback',
                  hint: 'Client and team feedback, stored in your own DB',
                ),
                const ShowcaseLockedSection(
                  title: 'Tasks',
                  hint: 'Feedback becomes an agent-ready task queue',
                ),
              ],
            ),
    );
  }
}
