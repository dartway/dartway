import 'package:dartway_example_flutter/auth/logic/auth_controller.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class VerifyOtpBlock extends ConsumerWidget {
  const VerifyOtpBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: AppText.title(context.l10n.enterSmsCode),
          ),
          const Gap(AppSpace.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: AppText.body(
              context.l10n.sentCodeToNumber(state.phoneRaw),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(AppSpace.s28),
          SizedBox(
            height: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: PinCodeTextFieldWidget(
                pinCode: state.otpRaw,
                onChanged: (pinCode) => ref
                    .read(authControllerProvider.notifier)
                    .update(otpRaw: pinCode),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: AppButton.primary(
              context.l10n.continueAction,
              requireValidation: true,
              onTap: dw.action(
                (_) => ref.read(authControllerProvider.notifier).verifyCode(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
