import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ShowcasePassportSection extends StatelessWidget {
  const ShowcasePassportSection({
    required this.heading,
    this.body,
    this.bullets = const [],
    this.numbered = false,
    super.key,
  });

  final String heading;
  final String? body;
  final List<String> bullets;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading.toUpperCase(), style: ShowcaseChrome.sectionTitle),
        const Gap(8),
        if (body != null) Text(body!, style: ShowcaseChrome.bodyText),
        for (final (index, bullet) in bullets.indexed) ...[
          if (index > 0 || body != null) const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  numbered ? '${index + 1}.' : '—',
                  style: ShowcaseChrome.bodyText,
                ),
              ),
              Expanded(child: Text(bullet, style: ShowcaseChrome.bodyText)),
            ],
          ),
        ],
        const Gap(20),
      ],
    );
  }
}
