import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'widgets/identity_change_sheet.dart';

/// How the member signs in: their phone and e-mail, each added or changed by a
/// code sent to the new one — without signing in again.
class ProfileIdentitySection extends StatelessWidget implements DwFeatureWidget {
  const ProfileIdentitySection({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'profile/identity',
    title: 'Sign-in identifiers',
    purpose:
        'A member keeps the ways they sign in current: a second identifier as '
        'a way back in, a new number when the old one is gone.',
    behaviors: [
      'Shows the phone and the e-mail the account signs in with, or that one '
          'is not added.',
      'Add or Change opens a sheet: the new value, then the code sent to it. '
          'Until the code is confirmed nothing changes.',
      'A changed identifier replaces the old one, which no longer signs in; '
          'an added one signs in beside the other.',
      'An identifier that belongs to another account is refused on the code '
          'step, after the right code, and nothing changes.',
    ],
    requirements: [
      'The server keeps the identifiers; the profile shows what the server '
          'answers, never a copy the app wrote.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = context.profile;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.body(l10n.identitySectionTitle),
          const Gap(4),
          for (final kind in DwIdentifierKind.values)
            _IdentityRow(
              kind: kind,
              value: switch (kind) {
                DwIdentifierKind.phone => profile.phone,
                DwIdentifierKind.email => profile.email,
              },
            ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.kind, required this.value});

  final DwIdentifierKind kind;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (kind) {
        DwIdentifierKind.phone => Icons.phone_outlined,
        DwIdentifierKind.email => Icons.alternate_email,
      }),
      title: AppText.caption(l10n.identifierKind(kind.name)),
      subtitle: AppText.body(current ?? l10n.identityNotSet),
      trailing: AppButton.text(
        current == null ? l10n.identityAddAction : l10n.identityChangeAction,
        onTap: dw.action(
          (context) => context.showAppBottomSheet<void>(
            child: IdentityChangeSheet(kind: kind, current: current),
          ),
        ),
      ),
    );
  }
}
