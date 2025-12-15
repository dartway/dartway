import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/auth/logic/auth_state.dart';
import 'package:project_name_flutter/auth/logic/auth_step.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

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
        const DwText('DartWay.dev', textStyle: AppText.title),
        const Gap(12),
        const DwText('Complete login or registration to continue',
            textStyle: AppText.body),
        const Spacer(
          flex: 1,
        ),
        DwButton.primary(
          'Registration',
          height: 40,
          width: 250,
          dwCallback: DwUiAction.create(
            () => ref
                .read(authStateProvider.notifier)
                .goTo(AuthStep.registration),
          ),
        ),
        const Gap(20),
        DwButton.secondary(
          'Login',
          height: 40,
          width: 250,
          dwCallback: DwUiAction.create(
            () => ref.read(authStateProvider.notifier).goTo(AuthStep.login),
          ),
        ),
        const Spacer(
          flex: 3,
        ),
      ],
    );
  }
}
