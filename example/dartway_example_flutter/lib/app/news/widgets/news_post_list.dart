import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class NewsPostList extends ConsumerWidget {
  const NewsPostList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Named once and used twice: watched below, and thrown away again by the
    // retry inside the error state. Writing the expression out a second time is
    // how a retry ends up refreshing a different provider than the one that
    // failed.
    final newsPosts = dw.repo.modelList<NewsPost>();

    return ref
        .watch(newsPosts)
        .dwBuildListAsync(
          loadingItemsCount: 5,
          // The feed is the whole point of this screen, so its failure gets a
          // picture of its own — "nothing was published" and "we could not ask"
          // must not look the same (dartway-clean-code §1.5a).
          errorBuilder: (_, _) => LoadFailedMessage(
            onRetry: dw.action((_) => ref.invalidate(newsPosts)),
          ),
          childBuilder: (posts) {
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
