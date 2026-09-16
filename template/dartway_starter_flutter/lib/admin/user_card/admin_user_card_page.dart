import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/shared/widgets/admin_scaffold.dart';
import 'package:dartway_starter_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'widgets/user_card_view.dart';

/// One member's card: everything the app knows about the person, and the
/// actions on their account.
class AdminUserCardPage extends ConsumerWidget implements DwFeatureWidget {
  const AdminUserCardPage({super.key, this.profileId});

  /// Whose card to show. Usually `null`: the id comes from the address, as on
  /// any page a link points to.
  final int? profileId;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/user-card',
    title: 'User card',
    purpose:
        'Everything the app knows about one person on one screen, and what an '
        'admin may change about them.',
    behaviors: [
      'Opens by an address holding the profile id, so it survives a page '
          'reload and can be passed on as a link.',
      'Shows the photo, the name, when the account was created and whether '
          'its terms were accepted, the news subscription, and every '
          'identifier it signs in with and when each was last confirmed.',
      'The role is changed here as in the table, after a confirmation.',
      'Everything on it is live: a change by the member or by another admin '
          'appears at once.',
      'An address naming no member says so.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = profileId ?? AdminParams.profileId.fromPathOrNull(context);
    if (id == null) {
      return AdminScaffold(
        title: l10n.adminUsers,
        body: AppText.body(l10n.userCardNotFound),
      );
    }
    final request = dw.request(GetUserCard(profileId: id));
    final card = ref.watch(request);

    if (card case AsyncError(
      error: DwRefusalException(:final refusal),
    ) when refusal.isCode(DwCoreRefusal.notFound)) {
      return AdminScaffold(
        title: l10n.adminUsers,
        body: AppText.body(l10n.userCardNotFound),
      );
    }

    return AdminScaffold(
      title: card.value?.profile.displayName ?? l10n.adminUsers,
      body: card.section(
        // Not a skeleton of the card: drawn over stand-in data it would show
        // a stranger's identifiers for a moment.
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onRetry: () => ref.read(request.notifier).refetch(),
        builder: (card) => UserCardView(card: card),
      ),
    );
  }
}
