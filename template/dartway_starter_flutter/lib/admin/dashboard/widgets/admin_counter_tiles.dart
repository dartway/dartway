import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Headline counters: one live view the server counts, republished by every
/// command that changes what it counts.
class AdminCounterTiles extends ConsumerWidget {
  const AdminCounterTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ref
        .watch(dw.request(const GetAdminCounters()))
        .section(
          loadingValue: const AdminCounters(
            members: 0,
            admins: 0,
            marketingOptIns: 0,
          ),
          onRetry: () =>
              ref.read(dw.request(const GetAdminCounters()).notifier).refetch(),
          // Equal tiles, whichever label wraps.
          builder: (counters) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CounterTile(
                    label: l10n.countMembers,
                    count: counters.members,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _CounterTile(
                    label: l10n.countAdmins,
                    count: counters.admins,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _CounterTile(
                    label: l10n.countMarketingOptIns,
                    count: counters.marketingOptIns,
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [AppText.title('$count'), const Gap(4), AppText.body(label)],
      ),
    );
  }
}
