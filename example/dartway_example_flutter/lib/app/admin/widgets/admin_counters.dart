import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Headline counters — placeholder tiles showing live model counts (no event
/// analytics yet).
class AdminCounters extends ConsumerWidget {
  const AdminCounters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _CounterTile(
            label: 'Members',
            child: ref.watchModelList<UserProfile>().dwBuildListAsync(
                  loadingItemsCount: 1,
                  childBuilder: (items) => _CountText(items.length),
                ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _CounterTile(
            label: 'Sessions',
            child: ref.watchModelList<ClubSession>().dwBuildListAsync(
                  loadingItemsCount: 1,
                  childBuilder: (items) => _CountText(items.length),
                ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _CounterTile(
            label: 'News',
            child: ref.watchModelList<NewsPost>().dwBuildListAsync(
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
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
