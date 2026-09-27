part of '../../ui_kit.dart';

/// Which way a number moved.
enum AppTrend { up, down, flat }

/// One number, large, with how it changed — `+12%` in the trend's colour —
/// and what the change is measured against.
class AppStatValue extends StatelessWidget {
  const AppStatValue({
    super.key,
    required this.value,
    this.change,
    this.trend = AppTrend.flat,
    this.caption,
  });

  final String value;

  /// The change as the viewer reads it: `+12%`, `−3`.
  final String? change;
  final AppTrend trend;

  /// What the change is against: "vs previous period".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final changeColor = switch (trend) {
      AppTrend.up => context.colorScheme.primary,
      AppTrend.down => context.colorScheme.error,
      AppTrend.flat => context.colorScheme.onSurfaceVariant,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style:
              (context.textTheme.displaySmall ?? const TextStyle(fontSize: 36))
                  .copyWith(color: context.colorScheme.onSurface),
        ),
        if (change case final change?)
          Row(
            children: [
              Icon(
                switch (trend) {
                  AppTrend.up => Icons.arrow_upward,
                  AppTrend.down => Icons.arrow_downward,
                  AppTrend.flat => Icons.arrow_forward,
                },
                size: 16,
                color: changeColor,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: AppTextStyle.body
                    .resolve(context)
                    .copyWith(color: changeColor),
              ),
              if (caption case final caption?) ...[
                const SizedBox(width: 6),
                Flexible(child: AppText.caption(caption)),
              ],
            ],
          ),
      ],
    );
  }
}
