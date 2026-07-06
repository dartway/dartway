import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/services/widgets/service_card.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold.inner(
      appBar: AppBar(title: AppText.title('Our services')),
      body: ref.watchModelList<ClubService>().dwBuildListAsync(
            loadingItemsCount: 4,
            childBuilder: (services) {
              if (services.isEmpty) {
                return Center(
                  child: AppText.body('The price list is coming soon'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: services.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => ServiceCard(
                  service: services[index],
                ),
              );
            },
          ),
    );
  }
}
