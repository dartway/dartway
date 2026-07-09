import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/auth/logic/auth_step.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

import '../logic/auth_state.dart';

class PhoneEntryBlock extends HookConsumerWidget {
  const PhoneEntryBlock({
    super.key,
    // required this.isAdminShadowMode,
  });

  // final bool isAdminShadowMode;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final state = ref.watch(authStateProvider);

    final isRegistration = switch (state.currentStep) {
      AuthStep.registration => true,
      AuthStep.login => false,
      _ => throw UnimplementedError(),
    };

    final l10n = context.l10n;

    return Column(
      children: [
        DwText(l10n.fillRegistrationData, textStyle: AppText.title),
        const Gap(36),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AppTextFormField(
              labelText: l10n.nameLabel,
              value: state.firstName,
              onChanged: (value) =>
                  ref.read(authStateProvider.notifier).update(firstName: value),
              validator: (p0) => p0 == null || p0.isEmpty || p0.length < 3
                  ? l10n.requiredField
                  : null,
            ),
          ),
        PhoneTextField(
          value: state.phoneRaw,
          onChanged: (value) =>
              ref.read(authStateProvider.notifier).update(phoneRaw: value),
        ),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: CheckboxFormField(
              value: state.allDocumentsAccepted,
              onChanged: (value) => ref
                  .read(authStateProvider.notifier)
                  .update(allDocumentsAccepted: value),
              validator: (value) => value != true ? l10n.youMustAgree : null,
              titleWidget: MultiLinkText.multi(
                textAlign: TextAlign.start,
                parts: [
                  MultiLinkTextPart(
                    l10n.agreeTermsPrefix,
                    l10n.offerLink,
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    null,
                    l10n.userAgreementLink,
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    l10n.acceptTermsPrefix,
                    l10n.dataPolicyLinkComma,
                    wipProgressNotificationCallback,
                  ),
                ],
              ),
            ),
          ),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: CheckboxFormField(
              value: state.marketingAgreed,
              onChanged: (value) => ref
                  .read(authStateProvider.notifier)
                  .update(marketingAgreed: value),
              titleWidget: MultiLinkText.multi(
                textAlign: TextAlign.start,
                parts: [
                  MultiLinkTextPart(
                    l10n.iGive,
                    l10n.consentLink,
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    l10n.marketingConsentText,
                    l10n.consentLink,
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    l10n.dataProcessingConsentText,
                    l10n.dataPolicyLink,
                    wipProgressNotificationCallback,
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(height: 20),
        DwButton.primary(
          l10n.continueAction,
          requireValidation: true,
          dwCallback: DwUiAction.create((_) async {
            await ref.read(authStateProvider.notifier).requestOtp();
          }),
        ),
        const Gap(24),
        isRegistration
            ? MultiLinkText.single(
                text: l10n.alreadyHaveAccount,
                linkText: l10n.loginAction,
                onLinkTap: DwUiAction.create(
                  (_) =>
                      ref.read(authStateProvider.notifier).goTo(AuthStep.login),
                ),
              )
            : MultiLinkText.single(
                text: l10n.stillNoAccount,
                linkText: l10n.registrationAction,
                onLinkTap: DwUiAction.create(
                  (_) => ref
                      .read(authStateProvider.notifier)
                      .goTo(AuthStep.registration),
                ),
              ),
      ],
    );
  }
}
