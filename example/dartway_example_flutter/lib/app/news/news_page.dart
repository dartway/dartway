import 'package:dartway_example_flutter/app/news/widgets/create_news_post_fab.dart';
import 'package:dartway_example_flutter/app/news/widgets/news_post_list.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/core/profile/profile_roles.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';

class NewsPage extends StatelessWidget implements DwFeature {
  const NewsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'news/feed',
    title: 'Club news',
    purpose: 'Members find out what the club is announcing.',
    behaviors: [
      'The publish button is shown to staff and to nobody else.',
      'A post published by anyone appears at the top without a refresh.',
    ],
    requirements: [
      'Only staff publishes, and only under their own name — the server '
          'refuses the command regardless of what the UI shows.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.clubNews)),
      body: const NewsPostList(),
      // Only staff publishes news — the server enforces the same rule.
      floatingActionButton: context.profile.isStaffMember
          ? const CreateNewsPostFab()
          : null,
    );
  }
}
