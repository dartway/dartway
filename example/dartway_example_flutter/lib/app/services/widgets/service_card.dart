import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, super.key});

  final ClubService service;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.body(
              service.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),
            AppText.caption(service.description),
            const Gap(8),
            AppText.caption(
              context.l10n.serviceDurationPrice(
                service.durationMinutes,
                service.price,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
