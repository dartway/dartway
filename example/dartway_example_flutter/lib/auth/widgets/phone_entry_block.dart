import 'package:dartway_example_flutter/auth/logic/auth_controller.dart';
import 'package:dartway_example_flutter/auth/logic/auth_step.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PhoneEntryBlock extends ConsumerWidget {
  const PhoneEntryBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    final isRegistration = switch (state.currentStep) {
      AuthStep.registration => true,
      AuthStep.login => false,
      _ => throw UnimplementedError(),
    };

    final l10n = context.l10n;

    return Column(
      children: [
        AppText.title(l10n.fillRegistrationData),
        const Gap(AppSpace.s36),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: AppTextFormField(
              labelText: l10n.nameLabel,
              value: state.firstName,
              onChanged: (value) => ref
                  .read(authControllerProvider.notifier)
                  .update(firstName: value),
              validator: (p0) => p0 == null || p0.isEmpty || p0.length < 3
                  ? l10n.requiredField
                  : null,
            ),
          ),
        PhoneTextField(
          labelText: l10n.phoneLabel,
          value: state.phoneRaw,
          onChanged: (value) =>
              ref.read(authControllerProvider.notifier).update(phoneRaw: value),
        ),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s24),
            child: CheckboxFormField(
              value: state.allDocumentsAccepted,
              onChanged: (value) => ref
                  .read(authControllerProvider.notifier)
                  .update(allDocumentsAccepted: value),
              validator: (value) => value != true ? l10n.youMustAgree : null,
              titleWidget: MultiLinkText.multi(
                textAlign: TextAlign.start,
                parts: [
                  MultiLinkTextPart(
                    l10n.agreeTermsPrefix,
                    l10n.offerLink,
                    dw.notImplementedYet,
                  ),
                  MultiLinkTextPart(
                    null,
                    l10n.userAgreementLink,
                    dw.notImplementedYet,
                  ),
                  MultiLinkTextPart(
                    l10n.acceptTermsPrefix,
                    l10n.dataPolicyLinkComma,
                    dw.notImplementedYet,
                  ),
                ],
              ),
            ),
          ),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s24),
            child: CheckboxFormField(
              value: state.marketingAgreed,
              onChanged: (value) => ref
                  .read(authControllerProvider.notifier)
                  .update(marketingAgreed: value),
              titleWidget: MultiLinkText.multi(
                textAlign: TextAlign.start,
                parts: [
                  MultiLinkTextPart(
                    l10n.iGive,
                    l10n.consentLink,
                    dw.notImplementedYet,
                  ),
                  MultiLinkTextPart(
                    l10n.marketingConsentText,
                    l10n.consentLink,
                    dw.notImplementedYet,
                  ),
                  MultiLinkTextPart(
                    l10n.dataProcessingConsentText,
                    l10n.dataPolicyLink,
                    dw.notImplementedYet,
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(height: AppSpace.s20),
        AppButton.primary(
          l10n.continueAction,
          requireValidation: true,
          onTap: dw.action(
            (_) => ref.read(authControllerProvider.notifier).requestCode(),
          ),
        ),
        const Gap(AppSpace.s24),
        isRegistration
            ? MultiLinkText.single(
                text: l10n.alreadyHaveAccount,
                linkText: l10n.loginAction,
                onLinkTap: dw.action(
                  (_) => ref
                      .read(authControllerProvider.notifier)
                      .goTo(AuthStep.login),
                ),
              )
            : MultiLinkText.single(
                text: l10n.stillNoAccount,
                linkText: l10n.registrationAction,
                onLinkTap: dw.action(
                  (_) => ref
                      .read(authControllerProvider.notifier)
                      .goTo(AuthStep.registration),
                ),
              ),
      ],
    );
  }
}
