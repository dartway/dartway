import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/common/app_scaffold.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/user_profile_provider.dart';
import 'package:dartway_starter_flutter/studio/logic/app_features.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

/// The starter home screen — delete it once your domain has its own.
///
/// It is deliberately not a placeholder: the app name below is read from the
/// database through the generic CRUD (`AppSetting`), so the very first screen
/// proves the whole path is alive — Postgres → server config → typed live list
/// → widget. Change the value in the admin panel and watch it update here
/// without a reload.
class HomePage extends ConsumerWidget implements DwFeature {
  const HomePage({super.key});

  @override
  DwFeatureSpec get dwFeature => AppFeatures.homeLiveSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watchUserProfile;

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(l10n.homeTitle)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.body(l10n.homeGreeting(user.firstName)),
                  const Gap(8),
                  // A live list from the server: one line, realtime, typed.
                  ref
                      .watchModelList<AppSetting>()
                      .dwBuildListAsync(
                        loadingItemsCount: 1,
                        childBuilder: (settings) {
                          final appName = settings
                              .where((s) => s.settingKey == 'appName')
                              .firstOrNull
                              ?.settingValue;
                          return AppText.caption(
                            appName == null
                                ? l10n.homeNoAppName
                                : l10n.homeAppNameFromDatabase(appName),
                          );
                        },
                      ),
                ],
              ),
            ),
            const Gap(16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.body(l10n.homeNextStepTitle),
                  const Gap(8),
                  AppText.caption(l10n.homeNextStepBody),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
