import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

import 'package:dartway_example_flutter/auth/logic/auth_state.dart';

class VerifyOtpBlock extends ConsumerWidget {
  const VerifyOtpBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.l),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
            child: AppText.title(context.l10n.enterSmsCode),
          ),
          const Gap(AppSpace.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
            child: AppText.body(
              context.l10n.sentCodeToNumber(state.phoneRaw),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(AppSpace.xxl),
          SizedBox(
            height: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: PinCodeTextFieldWidget(
                pinCode: state.otpRaw,
                onChanged: (pinCode) => ref
                    .read(authStateProvider.notifier)
                    .update(otpRaw: pinCode),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
            child: AppButton.primary(
              context.l10n.continueAction,
              requireValidation: true,
              onTap: dw.action(
                (_) => ref.read(authStateProvider.notifier).verifyCode(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
