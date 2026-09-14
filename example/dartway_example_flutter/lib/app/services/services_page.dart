import 'package:dartway_example_flutter/app/services/widgets/service_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ServicesPage extends ConsumerWidget implements DwFeature {
  const ServicesPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'services/price-list',
    title: 'Services and prices',
    purpose:
        'A member sees what the club offers and what it costs without having '
        'to ask at the desk.',
    behaviors: [
      'Services are listed as cards, alphabetically.',
      'A service an admin edits changes in place, and one they add appears at '
          'the top, without a refresh.',
      'An empty price list shows a "coming soon" message, not a blank screen.',
      'While the list loads, four placeholder cards are shown.',
      'A failed read says so and offers a retry.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold.inner(
      appBar: AppBar(title: AppText.title(context.l10n.ourServices)),
      body: ref
          .watch(dw.request(const ListClubServices()))
          .section(
            loadingValue: PlaceholderObjects.listOf(
              PlaceholderObjects.service,
              4,
            ),
            onRetry: () => ref
                .read(dw.request(const ListClubServices()).notifier)
                .refetch(),
            builder: (services) {
              if (services.isEmpty) {
                return Center(
                  child: AppText.body(context.l10n.priceListComingSoon),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: services.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    ServiceCard(service: services[index]),
              );
            },
          ),
    );
  }
}
