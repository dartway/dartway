import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

enum DwDefaultTextStyle implements DwTextStylePreset {
  multiLinkText,
  multiLinkTextLink;

  @override
  TextStyle resolveStyle(BuildContext context) {
    final theme = Theme.of(context);
    switch (this) {
      case DwDefaultTextStyle.multiLinkText:
        return theme.textTheme.bodyMedium ??
            const TextStyle(fontSize: 14, color: Colors.black);
      case DwDefaultTextStyle.multiLinkTextLink:
        return (theme.textTheme.bodyMedium ??
                const TextStyle(fontSize: 14, color: Colors.blue))
            .copyWith(color: theme.colorScheme.secondary);
    }
  }
}
