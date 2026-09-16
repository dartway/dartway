import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'logic/auth_state.dart';
import 'logic/auth_step.dart';
import 'widgets/code_entry_block.dart';
import 'widgets/consents_block.dart';
import 'widgets/identifier_entry_block.dart';

class AuthPage extends ConsumerWidget implements DwFeatureWidget {
  const AuthPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'auth/sign-in',
    title: 'Sign in',
    purpose:
        'One way in for everyone: a one-time code to a phone number or an '
        'e-mail. An identifier nobody has used yet becomes a new account.',
    behaviors: [
      'The person picks phone or e-mail, types it and asks for a code; an '
          'identifier that is not a valid phone or e-mail is refused before '
          'anything is sent.',
      'The code step shows where the code went and when a new one may be '
          'asked for; a wrong code says how many attempts are left.',
      'A code that would create an account first asks for a name and the '
          'terms, then verifies the same code again — nobody types it twice.',
      'An existing account is signed in by the code alone.',
    ],
    requirements: [
      'The server decides what an identifier is and whether an account '
          'exists: the app never learns it before the right code.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(authStateProvider.select((state) => state.step));

    return AppScaffold.inner(
      appBar: AppBar(
        leading: step.previousStep != null
            ? IconButton(
                onPressed: () => ref.read(authStateProvider.notifier).back(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        centerTitle: true,
        title: AppText.title(context.l10n.authStepTitle(step.name)),
      ),
      body: Form(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          // Every step starts at the top, whatever its height.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: switch (step) {
            AuthStep.identifier => const IdentifierEntryBlock(),
            AuthStep.code => const CodeEntryBlock(),
            AuthStep.consents => const ConsentsBlock(),
          },
        ),
      ),
    );
  }
}
