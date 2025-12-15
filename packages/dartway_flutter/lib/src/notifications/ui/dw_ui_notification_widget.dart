import 'package:flutter/material.dart';

import '../domain/dw_ui_notification.dart';

class DwUiNotificationWidget extends StatelessWidget {
  final DwUiNotification notification;

  const DwUiNotificationWidget({super.key, required this.notification});

  Icon? _icon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (notification.type) {
      case DwUiNotificationType.success:
        return Icon(Icons.check, color: scheme.primary);
      case DwUiNotificationType.warning:
        return Icon(Icons.warning_amber, color: scheme.secondary);
      case DwUiNotificationType.error:
        return Icon(Icons.error_outline, color: scheme.error);
      case DwUiNotificationType.info:
        return Icon(Icons.info_outline, color: scheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: Theme(
        data: theme.copyWith(extensions: const []),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_icon(context) case final icon?) icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
