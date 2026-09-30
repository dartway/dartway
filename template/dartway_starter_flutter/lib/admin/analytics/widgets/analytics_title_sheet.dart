import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Asks for a dashboard's title: a new one's, or a new title for one. Pops
/// with the title, trimmed.
class AnalyticsTitleSheet extends HookWidget {
  const AnalyticsTitleSheet({super.key, this.initial = ''});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = useState(initial);
    final trimmed = title.value.trim();
    final valid =
        trimmed.isNotEmpty &&
        trimmed.length <= DwAnalyticsDashboard.maxTitleLength &&
        trimmed != initial;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          value: title.value,
          onChanged: (value) => title.value = value,
          labelText: l10n.analyticsDashboardTitle,
          maxLength: DwAnalyticsDashboard.maxTitleLength,
        ),
        const Gap(AppSpace.m),
        AppButton.primary(
          l10n.saveAction,
          onTap: valid
              ? dw.action((context) => Navigator.of(context).pop(trimmed))
              : null,
        ),
      ],
    );
  }
}
