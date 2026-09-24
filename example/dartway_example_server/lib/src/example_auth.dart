import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../generated/dw_schema.dart';
import 'club_objects.dart';
import 'entities/club.dart';
import 'entities/people.dart';
import 'example_channels.dart';
import 'handlers/admin_handlers.dart';
import 'handlers/schedule_handlers.dart';

/// Signing in by a code to a phone, and the profile an account starts with.
abstract final class ExampleAuth {
  /// Sign-in by a one-time code to a phone number.
  static final config = DwAuthConfig(
    accountDeletion: DwAccountDeletion.byMember,
    normalize: (kind, raw) => switch (kind) {
      DwIdentifierKind.phone => ExampleAuth.normalizePhone(raw),
      DwIdentifierKind.email => null, // the club signs in by phone only
    },

    // Demo personas and store reviewers sign in with a fixed code set on
    // their profile; everyone else gets `null` — the framework's own
    // default, `codeLength` random digits (6, left unset here).
    generateCode: (ctx, kind, identifier, accountId) =>
        ExampleAuth._testCode(ctx, accountId),

    // The example sends no SMS: the code is written to the server log, which
    // is enough to sign in locally. A real project delivers it here — except
    // a demo persona's or a store reviewer's fixed code, which goes nowhere.
    deliverCode: (ctx, kind, identifier, code, accountId) async {
      if (await ExampleAuth._testCode(ctx, accountId) != null) return;
      stdout.writeln('Sign-in code for $identifier: $code');
    },

    // The profile is created with the account, in the same transaction: a
    // signed-in account without a profile cannot exist.
    onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
      final profile = await ExampleAuth.createProfile(
        ctx.db,
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
      ctx
        ..publish(adminChannel, await ctx.countAdminCounters())
        ..publish(adminChannel, ClubObjects.profile(profile));
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
            t.clientProfileId.equals(profile.id!) &
            t.status.equals(BookingStatus.booked),
        lock: DwRowLock.forUpdate,
      );
      for (final booking in held) {
        await ctx.db.sessionBookings.update(
          booking.copyWith(status: BookingStatus.cancelled),
        );
        final session = (await ctx.db.clubSessions.findById(
          booking.sessionId,
          lock: DwRowLock.forUpdate,
        ))!;
        final freed = await ctx.db.clubSessions.update(
          session.copyWith(bookedCount: session.bookedCount - 1),
        );
        ctx.publish(
          scheduleChannel,
          (await ClubObjects.sessions(ctx.db, [freed])).single,
        );
      }
      final tombstone = await ctx.db.userProfiles.update(
        profile.copyWith(
          firstName: '',
          lastName: const DwFieldPatch.clear(),
          phone: '',
          imageUrl: const DwFieldPatch.clear(),
          gender: const DwFieldPatch.clear(),
          testVerificationCode: const DwFieldPatch.clear(),
          agreedForMarketing: false,
          deletedAt: DwFieldPatch.set(DateTime.now()),
        ),
      );
      // The admins' members table holds the row: it must show what it became,
      // not what it was.
      ctx
        ..publish(adminChannel, ClubObjects.profile(tombstone))
        ..publish(adminChannel, await ctx.countAdminCounters());
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
      final profile = ClubObjects.profile(
        await ctx.db.userProfiles.update(current.copyWith(phone: phone)),
      );
      ctx
        ..publish(ExampleChannels.profileOf(change.accountId), profile)
        ..publish(adminChannel, profile);
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

  /// The profile a new account starts with. Separate from the hook so tools that
  /// create accounts without a running server (the dev seed) create the same row.
  static Future<UserProfileRow> createProfile(
    DwDatabaseHandle db,
    int accountId,
    String phone,
    Map<String, String> registration,
  ) => db.userProfiles.insert(
    UserProfileRow(
      accountId: accountId,
      phone: phone,
      firstName: registration['firstName']?.trim() ?? '',
      agreedForMarketing: registration['marketing'] == 'true',
      conditionsAcceptedAt: DateTime.now(),
    ),
  );

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
