import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';

import '../generated/dw_schema.dart';
import 'club_objects.dart';
import 'entities/people.dart';
import 'example_channels.dart';
import 'handlers/admin_handlers.dart';

/// Sign-in by a one-time code to a phone number.
final exampleAuth = DwAuthConfig(
  normalize: (kind, raw) => switch (kind) {
    DwIdentifierKind.phone => normalizePhone(raw),
    DwIdentifierKind.email => null, // the club signs in by phone only
  },

  // The example sends no SMS: the code is written to the server log, which is
  // enough to sign in locally. A real project delivers it here.
  deliverCode: (ctx, kind, identifier, code) async =>
      stdout.writeln('Sign-in code for $identifier: $code'),

  // Demo personas and store reviewers sign in with a fixed code set on their
  // profile.
  fixedCode: (ctx, kind, identifier, accountId) async {
    if (accountId == null) return null;
    final profile = await ctx.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    return profile?.testVerificationCode;
  },

  // The profile is created with the account, in the same transaction: a
  // signed-in account without a profile cannot exist.
  onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
    final profile = await createProfile(
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
      ..publish(adminChannel, await countAdminCounters(ctx))
      ..publish(adminChannel, ClubObjects.profile(profile));
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
      ..publish(profileOf(change.accountId), profile)
      ..publish(adminChannel, profile);
  },
);

/// The profile a new account starts with. Separate from the hook so tools that
/// create accounts without a running server (the dev seed) create the same row.
Future<UserProfileRow> createProfile(
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
String? normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
