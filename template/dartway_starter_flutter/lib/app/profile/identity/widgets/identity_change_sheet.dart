import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Adds or changes one identifier: the new value, then the code sent to it.
///
/// `DwRequestIdentifierCode` asks for the code; `DwConfirmIdentifier` confirms
/// it — with `replace` when the member already has one of this kind, so the
/// new value takes the old one's place instead of signing in beside it. The
/// profile is not read again: the server republishes it in the confirming
/// transaction, and the answer already carries it.
class IdentityChangeSheet extends HookWidget {
  const IdentityChangeSheet({
    required this.kind,
    required this.current,
    super.key,
  });

  final DwIdentifierKind kind;

  /// The identifier of [kind] the member has now; `null` adds one.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = useState('');
    final code = useState('');
    final ticket = useState<DwCodeTicket?>(null);
    final sent = ticket.value;

    Future<DwCallResult<DwCodeTicket>> requestCode() async {
      final result = await dw.command(
        DwRequestIdentifierCode(
          kind: kind,
          identifier:
              AuthIdentifier.normalize(kind, draft.value) ?? draft.value,
        ),
      );
      if (result case DwCallOk(:final value)) {
        code.value = '';
        ticket.value = value;
      }
      return result;
    }

    Future<DwCallResult<DwIdentityInfo>> confirm() async {
      final result = await dw.command(
        DwConfirmIdentifier(
          ticketId: sent!.id,
          code: code.value,
          replace: current != null,
        ),
      );
      // Taken by another account: the ticket is used up, and the way on is
      // another value.
      if (result case DwCallRefused(
        :final refusal,
      ) when refusal.isCode(DwAuthRefusal.identifierTaken)) {
        ticket.value = null;
      }
      return result;
    }

    return Form(
      key: ValueKey(sent?.id),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText.title(l10n.identitySheetTitle(kind.name)),
            const Gap(8),
            if (sent == null) ...[
              AppText.body(l10n.identitySheetIntro),
              const Gap(16),
              switch (kind) {
                DwIdentifierKind.phone => PhoneTextField(
                  labelText: l10n.phoneLabel,
                  hintText: l10n.phoneHint,
                  value: draft.value,
                  onChanged: (value) => draft.value = value,
                  validator: (value) =>
                      AuthIdentifier.normalize(kind, value) == null
                      ? l10n.invalidPhoneNumber
                      : null,
                ),
                DwIdentifierKind.email => AppTextFormField(
                  labelText: l10n.emailLabel,
                  hintText: l10n.emailHint,
                  value: draft.value,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => draft.value = value,
                  validator: (value) =>
                      AuthIdentifier.normalize(kind, value ?? '') == null
                      ? l10n.invalidEmail
                      : null,
                ),
              },
              const Gap(24),
              AppButton.primary(
                l10n.getCodeAction,
                requireValidation: true,
                onTap: dw.action((_) => requestCode()),
              ),
            ] else ...[
              AppText.body(l10n.codeSentTo(draft.value.trim())),
              const Gap(16),
              PinCodeTextFieldWidget(
                pinCode: code.value,
                onChanged: (value) => code.value = value,
              ),
              ResendCodeButton(
                availableAt: sent.resendAfter,
                onResend: dw.action((_) => requestCode()),
              ),
              const Gap(16),
              AppButton.primary(
                l10n.identityConfirmAction,
                requireValidation: true,
                onTap: dw.action(
                  (_) => confirm(),
                  onSuccessNotification: l10n.identitySaved(kind.name),
                  followUpIfMountedAction: (context, _) =>
                      Navigator.of(context).pop(),
                ),
              ),
              AppButton.text(
                l10n.changeIdentifierAction,
                onTap: dw.action((_) => ticket.value = null),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
