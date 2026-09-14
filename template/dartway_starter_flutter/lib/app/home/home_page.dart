import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_starter_flutter/core/dev/test_error_button.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_starter_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The first home screen — replace it once your domain has its own.
///
/// It is deliberately not a placeholder: the app name on it is a setting read
/// from the server, live, so the very first screen proves the whole path —
/// Postgres → handler → live request → widget. Change the name in the admin
/// panel and every open copy of this screen follows without a reload.
class HomePage extends ConsumerWidget implements DwFeature {
  const HomePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'home/live-settings',
    title: 'Home',
    purpose:
        'The first screen proves the whole path works: Postgres → handler → '
        'live request → widget.',
    behaviors: [
      'Greets the member by name.',
      'The app name comes from the server settings, not from a constant, and '
          'changing it in the admin panel updates this screen with no reload.',
      'A failed read says so and offers a retry — the one thing this screen '
          'exists to prove must not fail in silence.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = dw.request(const ListAppSettings());

    return AppScaffold.main(
      appBar: AppBar(
        title: AppText.title(l10n.homeTitle),
        actions: const [
          ConnectionStatusIndicator(),
          if (kDebugMode) TestErrorButton(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.title(l10n.helloUser(context.profile.firstName)),
                  const Gap(8),
                  ref
                      .watch(settings)
                      .section(
                        loadingValue: const <AppSetting>[],
                        onRetry: () => ref.read(settings.notifier).refetch(),
                        builder: (stored) => AppText.body(
                          l10n.homeAppName(
                            stored.valueOf(AppSettingKey.appName),
                          ),
                        ),
                      ),
                  const Gap(8),
                  AppText.caption(l10n.homeLiveHint),
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
