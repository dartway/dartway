import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

/// The news feed, newest first and live: a post published anywhere is
/// inserted in its place by the request's own sort, a removed one disappears.
/// Read a page at a time: the next page is asked for as the end of the list
/// comes near.
class NewsPostList extends StatelessWidget {
  const NewsPostList({super.key});

  @override
  Widget build(BuildContext context) => DwPagedListView<NewsPost>(
    request: const ListNews(),
    placeholder: PlaceholderObjects.newsPost,
    placeholderCount: 5,
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
    emptyBuilder: (context) =>
        Center(child: AppText.body(context.l10n.noNewsYet)),
    itemBuilder: (context, post) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: NewsPostCard(post: post),
    ),
  );
}
