import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_flutter/auth/logic/auth_state.dart';
import 'package:dartway_starter_flutter/auth/logic/auth_step.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

class GreetingBlock extends ConsumerWidget {
  const GreetingBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(
          flex: 2,
        ),
        // Your brand goes here — the one string every new project renames first.
        const AppText.title('DartwayStarter'),
        const Gap(12),
        AppText.body(context.l10n.completeLoginToContinue),
        const Spacer(
          flex: 1,
        ),
        AppButton.primary(
          context.l10n.registrationAction,
          height: 40,
          width: 250,
          onTap: dw.action(
            (_) => ref
                .read(authStateProvider.notifier)
                .goTo(AuthStep.registration),
          ),
        ),
        const Gap(20),
        AppButton.secondary(
          context.l10n.loginAction,
          height: 40,
          width: 250,
          onTap: dw.action(
            (_) => ref.read(authStateProvider.notifier).goTo(AuthStep.login),
          ),
        ),
        const Spacer(
          flex: 3,
        ),
      ],
    );
  }
}
