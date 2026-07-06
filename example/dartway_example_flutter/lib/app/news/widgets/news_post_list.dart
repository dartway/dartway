import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class NewsPostList extends ConsumerWidget {
  const NewsPostList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<NewsPost>().dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (posts) {
            if (posts.isEmpty) {
              return Center(
                child: AppText.body('No news yet — stay tuned!'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => NewsPostCard(
                post: posts[index],
              ),
            );
          },
        );
  }
}
