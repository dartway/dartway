import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/app/home/create_post_fab/create_post_fab.dart';
import 'package:project_name_flutter/app/home/feed_post_list/feed_post_list.dart';
import 'package:project_name_flutter/common/app_scaffold.dart';

import 'widgets/home_app_bar.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppScaffold.main(
      appBar: HomeAppBar(),
      body: FeedPostList(),
      floatingActionButton: CreatePostFab(),
    );
  }
}
