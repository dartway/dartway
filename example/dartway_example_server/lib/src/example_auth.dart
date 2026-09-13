import 'dart:io';

import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../generated/dw_schema.dart';
import 'entities/people.dart';
import 'projections.dart';
import 'handlers/admin_handlers.dart';

/// Sign-in by a one-time code to a phone number.
final exampleAuth = DwAuth(
  normalize: (kind, raw) => switch (kind) {
    DwIdentifierKind.phone => _normalizePhone(raw),
    DwIdentifierKind.email => null, // the club signs in by phone only
  },

  // The example sends no SMS: the code is written to the server log, which is
  // enough to sign in locally. A real project delivers it here.
  deliverCode: (ctx, kind, identifier, code) async =>
      stdout.writeln('Sign-in code for $identifier: $code'),

  // Demo personas and store reviewers sign in with a fixed code set on their
  // profile by an admin.
  fixedCode: (ctx, kind, identifier, accountId) async {
    if (accountId == null) return null;
    final profile = await ctx.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    return profile?.testVerificationCode;
  },

  // The profile is created with the account, in the same transaction: a
  // signed-in account without a profile cannot exist.
  onAccountCreated: (ctx, accountId, kind, identifier, registration) async {
    final profile = await createProfile(
      ctx.db,
      accountId,
      identifier,
      registration,
    );
    // The admin users table and the counters learn about the new member.
    ctx.publish(const DwChannel(ExampleChannel.admin), Views.profile(profile));
    await publishAdminCounters(ctx);
  },
);

/// The profile a new account starts with. Separate from the hook so tools that
/// create accounts without a running server (the dev seed) create the same row.
Future<UserProfile> createProfile(
  DwDb db,
  int accountId,
  String phone,
  Map<String, String> registration,
) => db.userProfiles.insert(
  UserProfile(
    accountId: accountId,
    phone: phone,
    firstName: registration['firstName']?.trim() ?? '',
    agreedForMarketing: registration['marketing'] == 'true',
    conditionsAcceptedAt: DateTime.now(),
  ),
);

/// Digits only; a Russian trunk prefix `8` becomes `7`. `null` for anything
/// that is not a plausible phone number.
String? _normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
