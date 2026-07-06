import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class NewsPostCard extends StatelessWidget {
  const NewsPostCard({required this.post, super.key});

  final NewsPost post;

  @override
  Widget build(BuildContext context) {
    final authorName = post.authorProfile?.firstName ?? '';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.title(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),
            AppText.body(post.text),
            const Gap(12),
            Row(
              children: [
                if (authorName.isNotEmpty)
                  Expanded(child: AppText.caption(authorName)),
                AppText.caption(
                  '${post.createdAt.dayLabel} · ${post.createdAt.timeLabel}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
