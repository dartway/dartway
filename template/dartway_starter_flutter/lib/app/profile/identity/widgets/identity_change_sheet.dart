import 'package:dartway_starter_flutter/app/profile/identity/logic/identity_change_controller.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Adds or changes one identifier: the new value, then the code sent to it
/// ([IdentityChangeController]).
class IdentityChangeSheet extends ConsumerWidget {
  const IdentityChangeSheet({
    required this.kind,
    required this.current,
    super.key,
  });

  final DwIdentifierKind kind;

  /// The identifier of [kind] the member has now; `null` adds one.
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final change = ref.watch(identityChangeProvider(kind));
    final controller = ref.read(identityChangeProvider(kind).notifier);
    final sent = change.ticket;

    return Form(
      key: ValueKey(sent?.id),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText.title(l10n.identitySheetTitle(kind.name)),
            const Gap(AppSpace.s8),
            if (sent == null) ...[
              AppText.body(l10n.identitySheetIntro),
              const Gap(AppSpace.s16),
              switch (kind) {
                DwIdentifierKind.phone => PhoneTextField(
                  labelText: l10n.phoneLabel,
                  hintText: l10n.phoneHint,
                  value: change.draft,
                  onChanged: controller.editDraft,
                  validator: (value) =>
                      AuthIdentifier.normalize(kind, value) == null
                      ? l10n.invalidPhoneNumber
                      : null,
                ),
                DwIdentifierKind.email => AppTextFormField(
                  labelText: l10n.emailLabel,
                  hintText: l10n.emailHint,
                  value: change.draft,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: controller.editDraft,
                  validator: (value) =>
                      AuthIdentifier.normalize(kind, value ?? '') == null
                      ? l10n.invalidEmail
                      : null,
                ),
              },
              const Gap(AppSpace.s24),
              AppButton.primary(
                l10n.getCodeAction,
                requireValidation: true,
                onTap: dw.action((_) => controller.requestCode()),
              ),
            ] else ...[
              AppText.body(l10n.codeSentTo(change.draft.trim())),
              const Gap(AppSpace.s16),
              PinCodeTextFieldWidget(
                pinCode: change.code,
                onChanged: controller.editCode,
              ),
              ResendCodeButton(
                availableAt: sent.resendAfter,
                onResend: dw.action((_) => controller.requestCode()),
              ),
              const Gap(AppSpace.s16),
              AppButton.primary(
                l10n.identityConfirmAction,
                requireValidation: true,
                onTap: dw.action(
                  (_) => controller.confirm(replace: current != null),
                  onSuccessNotification: l10n.identitySaved(kind.name),
                  followUpIfMountedAction: (context, _) =>
                      Navigator.of(context).pop(),
                ),
              ),
              AppButton.text(
                l10n.changeIdentifierAction,
                onTap: dw.action((_) => controller.changeIdentifier()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
