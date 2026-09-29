import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The member's name for the card's title, `null` until the card has
/// loaded — the page's chrome shows its own fallback meanwhile, and the
/// card's body answers for loading and failing through its `DwReadBuilder`.
final userCardNameProvider = Provider.autoDispose.family<String?, int>(
  (ref, profileId) => ref.watch(
    dw
        .request(GetUserCard(profileId: profileId))
        .select((card) => card.value?.profile.displayName),
  ),
);
