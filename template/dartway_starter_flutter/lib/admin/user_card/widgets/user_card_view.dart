import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/shared/widgets/role_picker.dart';
import 'package:dartway_starter_flutter/shared/widgets/user_avatar.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// The card's content: who the person is, how they sign in, their role.
class UserCardView extends StatelessWidget {
  const UserCardView({required this.card, super.key});

  final UserCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = card.profile;
    final termsAcceptedAt = card.termsAcceptedAt;

    return ListView(
      children: [
        Row(
          children: [
            UserAvatar(avatarUrl: profile.avatarUrl, radius: 36),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.title(profile.displayName),
                  const Gap(4),
                  AppText.caption(
                    l10n.userCardJoined(profile.joinedAt.dateLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Gap(16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.body(l10n.userCardIdentifiers),
              for (final identifier in card.identifiers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (identifier.kind) {
                    DwIdentifierKind.phone => Icons.phone_outlined,
                    DwIdentifierKind.email => Icons.alternate_email,
                  }),
                  title: AppText.body(identifier.value),
                  subtitle: AppText.caption(switch (identifier.verifiedAt) {
                    final at? => l10n.identifierVerified(at.dateLabel),
                    null => l10n.identifierNotVerified,
                  }),
                ),
            ],
          ),
        ),
        const Gap(12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: AppText.body(l10n.roleLabel)),
                  RolePicker(user: profile),
                ],
              ),
              const Gap(8),
              AppText.caption(
                termsAcceptedAt == null
                    ? l10n.userCardTermsNotAccepted
                    : l10n.userCardTermsAccepted(termsAcceptedAt.dateLabel),
              ),
              const Gap(4),
              AppText.caption(
                l10n.userCardMarketing('${profile.agreedForMarketing}'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
