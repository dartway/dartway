// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// /// A widget that displays a notification badge based on a provider
// class NotificationBadge extends ConsumerWidget {
//   const NotificationBadge({
//     super.key,
//     required this.notificationProvider,
//     this.badgeColor,
//     this.textColor,
//     this.minSize = 16.0,
//   });

//   final ProviderListenable<int> notificationProvider;
//   final Color? badgeColor;
//   final Color? textColor;
//   final double minSize;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final count = ref.watch(notificationProvider);

//     if (count <= 0) {
//       return const SizedBox.shrink();
//     }

//     final theme = Theme.of(context);
//     final badgeColor = this.badgeColor ?? theme.colorScheme.error;
//     final textColor = this.textColor ?? theme.colorScheme.onError;

//     return Container(
//       padding: const EdgeInsets.all(2),
//       decoration: BoxDecoration(
//         color: badgeColor,
//         borderRadius: BorderRadius.circular(minSize / 2),
//       ),
//       constraints: BoxConstraints(
//         minWidth: minSize,
//         minHeight: minSize,
//       ),
//       child: Text(
//         '$count',
//         style: theme.textTheme.labelSmall!.copyWith(
//           color: textColor,
//           fontWeight: FontWeight.w600,
//         ),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }
// }
