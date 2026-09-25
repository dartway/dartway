import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'profile_rows.dart';

/// Rows → the data objects clients see. Related data is loaded in one query
/// per relation for the whole batch, never per row.
abstract final class AppObjects {
  static Future<List<UserProfile>> profiles(
    DwCallContext ctx,
    List<UserProfileRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final identities = await ctx.accounts.listIdentitiesOf(
      rows.map((row) => row.accountId),
    );
    final avatarIds = {for (final row in rows) ?row.avatarFileId};
    // Asked only when there are photos: a server without file storage has no
    // file ids to resolve, and `ctx.files` refuses to work there.
    final avatarUrls = avatarIds.isEmpty
        ? const <int, String>{}
        : await ctx.files.publicUrls(avatarIds);
    return [
      for (final row in rows)
        _profile(
          row,
          identities[row.accountId] ?? const [],
          avatarUrls[row.avatarFileId],
        ),
    ];
  }

  static Future<UserProfile> profile(
    DwCallContext ctx,
    UserProfileRow row,
  ) async => (await profiles(ctx, [row])).single;

  static Future<UserCard> card(DwCallContext ctx, UserProfileRow row) async {
    final identities = await ctx.accounts.listIdentities(row.accountId);
    return UserCard(
      id: row.id!,
      profile: await profile(ctx, row),
      identifiers: [
        for (final identity in identities)
          UserIdentifier(
            id: identity.id,
            kind: identity.kind,
            value: identity.value,
            addedAt: identity.createdAt,
            verifiedAt: identity.verifiedAt,
          ),
      ],
      termsAcceptedAt: row.termsAcceptedAt,
    );
  }

  /// An account may hold several identifiers of a kind; the profile shows the
  /// oldest — the one a change by code (`DwConfirmIdentifier` with `replace`)
  /// rewrites in place. Identities come oldest first.
  static String? _oldest(
    List<DwIdentityInfo> identities,
    DwIdentifierKind kind,
  ) => identities.where((identity) => identity.kind == kind).firstOrNull?.value;

  static UserProfile _profile(
    UserProfileRow row,
    List<DwIdentityInfo> identities,
    String? avatarUrl,
  ) => UserProfile(
    id: row.id!,
    accountId: row.accountId,
    firstName: row.firstName,
    lastName: row.lastName,
    gender: row.gender,
    avatarUrl: avatarUrl,
    phone: _oldest(identities, DwIdentifierKind.phone),
    email: _oldest(identities, DwIdentifierKind.email),
    role: row.role,
    agreedForMarketing: row.agreedForMarketing,
    joinedAt: row.createdAt,
  );
}
