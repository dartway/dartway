import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/auth/logic/auth_step.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

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

    // print('isRegistration: $isRegistration');

    return Column(
      children: [
        const DwText('Fill registration data', textStyle: AppText.title),
        const Gap(36),
        if (isRegistration)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AppTextFormField(
              labelText: 'Name',
              value: state.firstName,
              onChanged: (value) =>
                  ref.read(authStateProvider.notifier).update(firstName: value),
              validator: (p0) => p0 == null || p0.isEmpty || p0.length < 3
                  ? 'Required field'
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
              validator: (value) => value != true ? 'You must agree' : null,
              titleWidget: MultiLinkText.multi(
                textAlign: TextAlign.start,
                parts: [
                  MultiLinkTextPart(
                    'I am familiar with and agree to the terms of the',
                    'offer,',
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    null,
                    'user agreement,',
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    'I accept the terms of the',
                    'data processing policy,',
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
                    'I give',
                    'consent',
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    'on receiving informational and promotional mailings, therefore I give',
                    'consent',
                    wipProgressNotificationCallback,
                  ),
                  MultiLinkTextPart(
                    'on processing personal data in accordance with the',
                    'data processing policy',
                    wipProgressNotificationCallback,
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(height: 20),
        DwButton.primary(
          'Continue',
          requireValidation: true,
          dwCallback: DwUiAction.create(() async {
            await ref.read(authStateProvider.notifier).requestOtp();
          }),
        ),
        const Gap(24),
        isRegistration
            ? MultiLinkText.single(
                text: 'Already have an account? ',
                linkText: 'Login',
                onLinkTap: DwUiAction.create(
                  () =>
                      ref.read(authStateProvider.notifier).goTo(AuthStep.login),
                ),
              )
            : MultiLinkText.single(
                text: 'Still no account? ',
                linkText: 'Registration',
                onLinkTap: DwUiAction.create(
                  () => ref
                      .read(authStateProvider.notifier)
                      .goTo(AuthStep.registration),
                ),
              ),
      ],
    );
  }
}
