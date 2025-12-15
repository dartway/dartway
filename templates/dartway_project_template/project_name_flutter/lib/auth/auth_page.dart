import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/auth/logic/auth_step.dart';
import 'package:project_name_flutter/auth/widgets/phone_entry_block.dart';
import 'package:project_name_flutter/auth/widgets/verify_otp_block.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

import '../common/app_scaffold.dart';
import 'logic/auth_state.dart';
import 'widgets/greeting_block.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);

    return AppScaffold.inner(
      requireUser: false,
      appBar: AppBar(
        leading: state.currentStep.previousStep != null
            ? IconButton(
                onPressed: () => ref
                    .read(authStateProvider.notifier)
                    .goTo(state.currentStep.previousStep!),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        centerTitle: true,
        title: state.currentStep.title != null
            ? AppText.title(state.currentStep.title!)
            : null,
      ),
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state.currentStep) {
                AuthStep.greeting => const GreetingBlock(),
                AuthStep.registration ||
                AuthStep.login =>
                  const PhoneEntryBlock(),
                AuthStep.registrationConfirmation ||
                AuthStep.loginConfirmation =>
                  const VerifyOtpBlock(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
