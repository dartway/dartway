import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../ui_kit/ui_kit.dart';
import 'app_l10n.dart';

/// Shown over the whole app once this build can no longer talk to its server.
///
/// The framework puts it in place of the app, above its `MaterialApp`, so it
/// brings its own. There is no store link here yet: once the app is published,
/// the button that opens its store page goes under the text.
class UpdateRequiredPage extends ConsumerWidget {
  const UpdateRequiredPage({required this.refusal, super.key});

  /// `dw.updateRequired` or `dw.protocolUnsupported`.
  final DwCallRefusal refusal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final l10n = context.l10n;
          final updateRequired = refusal.isCode(DwCoreRefusal.updateRequired);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIconView(AppIcon.brandMark, size: 64),
                    const SizedBox(height: 24),
                    AppText.title(
                      updateRequired
                          ? l10n.updateRequiredTitle
                          : l10n.serverMismatchTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    AppText.body(
                      updateRequired
                          ? l10n.updateRequiredBody
                          : l10n.serverMismatchBody,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
