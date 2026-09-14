import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The news feed, newest first and live: a post published anywhere is
/// inserted in its place by the request's own sort, a removed one disappears.
class NewsPostList extends ConsumerWidget {
  const NewsPostList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dw.request(const ListNews()))
        .section(
          loadingValue: PlaceholderObjects.listOf(
            PlaceholderObjects.newsPost,
            5,
          ),
          onRetry: () =>
              ref.read(dw.request(const ListNews()).notifier).refetch(),
          builder: (posts) {
            if (posts.isEmpty) {
              return Center(child: AppText.body(context.l10n.noNewsYet));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => NewsPostCard(post: posts[index]),
            );
          },
        );
  }
}
