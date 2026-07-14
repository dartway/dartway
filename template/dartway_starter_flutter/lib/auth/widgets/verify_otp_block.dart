import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

import '../logic/auth_state.dart';

class VerifyOtpBlock extends HookConsumerWidget {
  const VerifyOtpBlock({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText.title(
              context.l10n.enterSmsCode,
            ),
          ),
          const Gap(12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText.body(
              context.l10n.sentCodeToNumber(state.phoneRaw),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(28),
          SizedBox(
            height: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PinCodeTextFieldWidget(
                pinCode: state.otpRaw,
                onChanged: (pinCode) => ref
                    .read(authStateProvider.notifier)
                    .update(otpRaw: pinCode),
              ),
            ),
          ),
          // const Gap(14),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: ResendCodeButton(onPressed: () async {
          //     await ref.read(authStateProvider.notifier).requestOtp(
          //           isAdminMode: isAdminShadowMode,
          //         );
          //   }),
          // ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppButton.primary(
              context.l10n.continueAction,
              requireValidation: true,
              onTap: DwUiAction.create(
                (_) => ref.read(authStateProvider.notifier).verifyOtp(),
              ),
            ),
          ),
          // if (keyboardHeight.value > 10) ...[
          //   const Gap(16),
          //   AppDecoratedBox.grayWithOnlyTopBorder(
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(
          //         vertical: 13,
          //         horizontal: 12,
          //       ),
          //       child: Row(
          //         mainAxisAlignment: MainAxisAlignment.end,
          //         children: [
          //           InkWell(
          //             onTap: () => focusNode.unfocus(),
          //             child: const ZAppText.sFProBodyRegularBlue(
          //               'Done',
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ] else
          //   Gap(24 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
