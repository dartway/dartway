import 'package:dartway_starter_flutter/auth/logic/auth_controller.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The code that was sent, and a new one once the server allows it.
class CodeEntryBlock extends ConsumerWidget {
  const CodeEntryBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final notifier = ref.read(authControllerProvider.notifier);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(AppSpace.s16),
        AppText.title(l10n.codeTitle, textAlign: TextAlign.center),
        const Gap(AppSpace.s12),
        AppText.body(
          l10n.codeSentTo(state.rawIdentifier.trim()),
          textAlign: TextAlign.center,
        ),
        const Gap(AppSpace.s28),
        PinCodeTextFieldWidget(
          pinCode: state.codeRaw,
          onChanged: (code) => notifier.update(codeRaw: code),
        ),
        const Gap(AppSpace.s8),
        ResendCodeButton(
          availableAt: state.resendAvailableAt,
          onResend: dw.action((_) => notifier.requestCode()),
        ),
        const Spacer(),
        AppButton.primary(
          l10n.continueAction,
          requireValidation: true,
          onTap: dw.action((_) => notifier.verifyCode()),
        ),
        const Gap(AppSpace.s8),
        AppButton.text(
          l10n.changeIdentifierAction,
          onTap: dw.action((_) => notifier.back()),
        ),
      ],
    );
  }
}
