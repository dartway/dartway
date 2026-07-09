import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/app/news/widgets/create_news_post_fab.dart';
import 'package:dartway_example_flutter/app/news/widgets/news_post_list.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/core/user_profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.clubNews)),
      body: const NewsPostList(),
      // Only staff publishes news — the server enforces the same rule.
      floatingActionButton: ref.watchUserProfile.isStaffMember
          ? const CreateNewsPostFab()
          : null,
    );
  }
}
