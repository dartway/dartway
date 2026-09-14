import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logic/auth_state.dart';

/// Phone or e-mail, and the button that asks for a code.
class IdentifierEntryBlock extends ConsumerWidget {
  const IdentifierEntryBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(24),
        // The mark a new project replaces first. The screen names an icon,
        // not a file: swap the asset and the path in `AppIcon`.
        const Center(child: AppIconView(AppIcon.brandMark, size: 64)),
        const Gap(24),
        AppText.body(l10n.authIntro, textAlign: TextAlign.center),
        const Gap(24),
        SegmentedButton<DwIdentifierKind>(
          segments: [
            for (final kind in DwIdentifierKind.values)
              ButtonSegment(
                value: kind,
                label: Text(l10n.identifierKind(kind.name)),
                icon: Icon(switch (kind) {
                  DwIdentifierKind.phone => Icons.phone_outlined,
                  DwIdentifierKind.email => Icons.alternate_email,
                }),
              ),
          ],
          selected: {state.kind},
          onSelectionChanged: (selected) =>
              notifier.update(kind: selected.single),
        ),
        const Gap(16),
        switch (state.kind) {
          DwIdentifierKind.phone => PhoneTextField(
            key: const ValueKey(DwIdentifierKind.phone),
            labelText: l10n.phoneLabel,
            hintText: l10n.phoneHint,
            value: state.phoneRaw,
            onChanged: (value) => notifier.update(phoneRaw: value),
            validator: (value) =>
                AuthIdentifier.normalize(DwIdentifierKind.phone, value) == null
                ? l10n.invalidPhoneNumber
                : null,
          ),
          DwIdentifierKind.email => AppTextFormField(
            key: const ValueKey(DwIdentifierKind.email),
            labelText: l10n.emailLabel,
            hintText: l10n.emailHint,
            value: state.emailRaw,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (value) => notifier.update(emailRaw: value),
            validator: (value) =>
                AuthIdentifier.normalize(DwIdentifierKind.email, value ?? '') ==
                    null
                ? l10n.invalidEmail
                : null,
          ),
        },
        const Spacer(),
        AppButton.primary(
          l10n.getCodeAction,
          requireValidation: true,
          onTap: dw.action((_) => notifier.requestCode()),
        ),
        const Gap(16),
      ],
    );
  }
}
