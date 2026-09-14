import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logic/auth_state.dart';

/// What a new account needs before the code creates it: a name and the terms
/// accepted, news and offers optional.
class ConsentsBlock extends ConsumerWidget {
  const ConsentsBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          AppText.body(l10n.consentsIntro(state.rawIdentifier.trim())),
          const Gap(24),
          AppTextFormField(
            labelText: l10n.nameLabel,
            value: state.firstName,
            autofillHints: const [AutofillHints.givenName],
            onChanged: (value) => notifier.update(firstName: value),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.requiredField : null,
          ),
          const Gap(16),
          CheckboxFormField(
            value: state.termsAccepted,
            onChanged: (value) => notifier.update(termsAccepted: value),
            validator: (value) => value ? null : l10n.youMustAgree,
            // The documents themselves are the project's to publish: the links
            // say so until they point somewhere.
            titleWidget: MultiLinkText.multi(
              textAlign: TextAlign.start,
              parts: [
                MultiLinkTextPart(
                  l10n.termsConsentPrefix,
                  l10n.termsLink,
                  wipProgressNotificationCallback,
                ),
                MultiLinkTextPart(
                  l10n.termsConsentMiddle,
                  l10n.privacyLink,
                  wipProgressNotificationCallback,
                ),
              ],
            ),
          ),
          const Gap(8),
          CheckboxFormField(
            value: state.marketingAgreed,
            onChanged: (value) => notifier.update(marketingAgreed: value),
            titleWidget: AppText.body(l10n.marketingConsent),
          ),
          const Gap(32),
          AppButton.primary(
            l10n.createAccountAction,
            requireValidation: true,
            onTap: dw.action((_) => notifier.verifyCode()),
          ),
        ],
      ),
    );
  }
}
