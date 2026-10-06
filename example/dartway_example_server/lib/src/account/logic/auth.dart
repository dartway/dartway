import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/admin/admin_publications.dart';
import 'package:dartway_example_server/src/bookings/bookings_changes.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/profile/profile_changes.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Signing in by a code to a phone, and the profile an account starts with.
abstract final class AccountAuth {
  /// Sign-in by a one-time code to a phone number.
  static final config = DwAuthConfig(
    accountDeletion: DwAccountDeletion.byMember,
    normalize: (kind, raw) => switch (kind) {
      DwIdentifierKind.phone => AccountAuth.normalizePhone(raw),
      DwIdentifierKind.email => null, // the club signs in by phone only
    },

    // Demo personas and store reviewers sign in with a fixed code set on
    // their profile; everyone else gets `null` — the framework's own
    // default, `codeLength` random digits (6, left unset here).
    generateCode: (ctx, kind, identifier, accountId) =>
        AccountAuth._testCode(ctx, accountId),

    // Explicit choices may be allowlisted with allowedDeliveryHints and read
    // through ctx.deliveryHint here. This example uses the default only.
    // The example sends no SMS: the code is written to the server log, which
    // is enough to sign in locally. A real project delivers it here — except
    // a demo persona's or a store reviewer's fixed code, which goes nowhere.
    deliverCode: (ctx, kind, identifier, code, accountId) async {
      if (await AccountAuth._testCode(ctx, accountId) != null) return;
      stdout.writeln('Sign-in code for $identifier: $code');
    },

    // The profile is created with the account, in the same transaction: a
    // signed-in account without a profile cannot exist.
    onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
      final profile = await ProfileChanges.create(
        ctx,
        accountId,
        identifier,
        switch (origin) {
          DwSignInOrigin(:final registration) => registration,
          // An account a tool made (the dev seed, an admin bootstrap) has no
          // sign-up form behind it.
          DwToolOrigin() => const {},
        },
      );
      // The newcomer goes to the admins: the dashboard counts them, and a
      // members table page reads itself again — a new row moves the paging and
      // the total, which only the server can compute.
      ctx.publish(AppChannels.admin, ProfileObjects.profile(profile));
      await AdminPublications.counters(ctx);
    },

    // Deleting an account leaves a tombstone, not a hole. The person goes:
    // name, phone, photo, the code they signed in with. The profile row stays,
    // because other people's content points at it — their messages in a staff
    // chat, the news they wrote, the reviews of visits the club counted — and
    // a club that loses those loses somebody else's history, not theirs. What
    // is left says one thing: a member who left.
    //
    // `user_profile.account_id` is `ON DELETE SET NULL`, so the framework's own
    // deletion of the account unlinks the row a moment after this hook.
    onAccountDeleting: (ctx, accountId) async {
      final profile = await ctx.db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(accountId),
      );
      if (profile == null) return;
      // Spots held for sessions still to come go back to the club: nobody is
      // coming, and the next member should be able to book them.
      final held = await ctx.db.sessionBookings.find(
        where: (t) =>
            t.clientProfileId.equals(profile.id) &
            t.status.equals(BookingStatus.booked),
        lock: DwRowLock.forUpdate,
      );
      for (final booking in held) {
        await BookingsChanges.cancel(ctx, booking, client: profile);
      }
      await ProfileChanges.tombstone(ctx, profile);
      await AdminPublications.counters(ctx);
    },

    // The profile shows the phone the member signs in with. The framework owns
    // it: a member who changes it by code (`DwConfirmIdentifier` with
    // `replace`) changes it here too, in the same transaction.
    onIdentifierChanged: (ctx, change) async {
      final phone = change.current;
      if (change.kind != DwIdentifierKind.phone || phone == null) return;
      final current = await ctx.db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(change.accountId),
      );
      if (current == null || current.phone == phone) return;
      await ProfileChanges.changePhone(ctx, current, phone);
    },
  );

  /// [accountId]'s fixed sign-in code, or `null` for an account without one
  /// (every ordinary member) or no account at all. Cached on [ctx]: both
  /// `generateCode` and `deliverCode` ask this in the same request, and it is
  /// one query either way.
  static Future<String?> _testCode(DwCallContext ctx, int? accountId) =>
      ctx.memo(#exampleTestCode, () async {
        if (accountId == null) return null;
        final profile = await ctx.db.userProfiles.findFirst(
          where: (t) => t.accountId.equals(accountId),
        );
        return profile?.testVerificationCode;
      });

  /// Digits only; a Russian trunk prefix `8` becomes `7`. `null` for anything
  /// that is not a plausible phone number.
  static String? normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    return digits.length >= 10 && digits.length <= 15 ? digits : null;
  }
}
