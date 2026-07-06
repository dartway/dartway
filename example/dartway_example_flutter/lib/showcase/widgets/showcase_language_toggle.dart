import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_language_provider.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_screen_spec.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ShowcaseLanguageToggle extends ConsumerWidget {
  const ShowcaseLanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(showcaseLanguageStateProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final language in ShowcaseLanguage.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: InkWell(
              borderRadius: ShowcaseChrome.chipRadius,
              onTap: () => ref
                  .read(showcaseLanguageStateProvider.notifier)
                  .select(language),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: language == selected
                      ? ShowcaseChrome.chipActiveColor
                      : ShowcaseChrome.chipColor,
                  borderRadius: ShowcaseChrome.chipRadius,
                ),
                child: Text(
                  language.name.toUpperCase(),
                  style: ShowcaseChrome.chipLabel,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
