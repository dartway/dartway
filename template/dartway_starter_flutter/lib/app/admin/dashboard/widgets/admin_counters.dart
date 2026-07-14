import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

/// Headline counters — live model counts, one tile per model.
///
/// Copy a tile per model you add: the count is a live list, so it updates by
/// itself when anyone writes the model anywhere.
class AdminCounters extends ConsumerWidget {
  const AdminCounters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _CounterTile(
            label: l10n.countMembers,
            child: ref.watchModelList<UserProfile>().dwBuildListAsync(
                  loadingItemsCount: 1,
                  childBuilder: (items) => _CountText(items.length),
                ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _CounterTile(
            label: l10n.countSettings,
            child: ref.watchModelList<AppSetting>().dwBuildListAsync(
                  loadingItemsCount: 1,
                  childBuilder: (items) => _CountText(items.length),
                ),
          ),
        ),
      ],
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const Gap(4),
          AppText.body(label),
        ],
      ),
    );
  }
}

class _CountText extends StatelessWidget {
  const _CountText(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => AppText.title('$count');
}
