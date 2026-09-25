import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import 'channels.dart';
import '../profile/profile_rows.dart';
import '../profile/profile_objects.dart';
import '../profile/profile_publications.dart';

/// The delivery a deploying project plugs into [AppAuth.config] — narrower
/// than `DwAuthConfig.deliverCode` itself, because [AppAuth] already answers
/// the one question every project would otherwise have to ask again (is this
/// a test account's fixed code, and if so say nothing).
typedef CodeDelivery =
    Future<void> Function(
      DwCallContext ctx,
      DwIdentifierKind kind,
      String identifier,
      String code,
    );

/// Signing in: the auth configuration, and the profile an account is created
/// with.
abstract final class AppAuth {
  /// Sign-in by a one-time code to a phone number or an e-mail address.
  ///
  /// [deliverCode] sends the code. By default it is written to the server log:
  /// the template sends no SMS and no e-mail, which is enough to sign in locally.
  /// **A deployed project delivers it here** — an SMS gateway for phones, a mail
  /// service for e-mail — and the log line goes. A store reviewer's or a demo
  /// persona's fixed code (below) never reaches it: [deliverCode] here wraps
  /// what is passed in and skips the call for those, so a deploying project's
  /// delivery does not have to know about test accounts.
  ///
  /// [resendDelay] is the pause before another code may be asked for the same
  /// identifier; the app counts it down from the ticket's `resendAfter`.
  static DwAuthConfig config({
    CodeDelivery? deliverCode,
    Duration resendDelay = const Duration(seconds: 60),
  }) => DwAuthConfig(
    accountDeletion: DwAccountDeletion.byMember,
    // One rule on both sides: the app normalizes what it sends with the same
    // function.
    normalize: AuthIdentifier.normalize,

    // Store reviewers, demo personas and end-to-end tests sign in with a fixed
    // code set on their profile; nobody else has one — `null` for them, the
    // framework's own default, `codeLength` random digits (6, left unset).
    generateCode: (ctx, kind, identifier, accountId) =>
        AppAuth._testCode(ctx, accountId),

    deliverCode: (ctx, kind, identifier, code, accountId) async {
      if (await AppAuth._testCode(ctx, accountId) != null) return;
      await (deliverCode ?? _logCode)(ctx, kind, identifier, code);
    },

    // The profile is created with the account, in the same transaction: a
    // signed-in account without a profile cannot exist. A refusal here rolls the
    // account back and leaves the code usable.
    onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
      final profile = await AppAuth.createProfile(ctx, accountId, origin);
      // The newcomer goes to the admins: the dashboard counts them, and a
      // members table page reads itself again — a new row moves the paging and
      // the total, which only the server can compute.
      ctx
        ..publish(
          AppChannels.admin,
          await AppPublications.countAdminCounters(ctx.db),
        )
        ..publish(AppChannels.admin, await AppObjects.profile(ctx, profile));
    },

    // The profile shows the phone and the e-mail an account signs in with, read
    // from the framework's identities rather than copied into the profile row —
    // so there is nothing to write here, only to tell: every change the
    // framework makes (a member attaching or replacing one by code) republishes
    // the profile to its owner and the admins, in the changing transaction.
    onIdentifierChanged: (ctx, change) async {
      final profile = await ctx.db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(change.accountId),
      );
      if (profile != null) await AppPublications.profile(ctx, profile);
    },

    // Deleting an account (`DwDeleteMyAccount`) takes the starter's profile
    // with it: `user_profile.account_id` is `ON DELETE CASCADE`, and the
    // profile is the only row this project keeps about a person. Declared
    // rather than left to the cascade alone — the server refuses to start
    // when a project's rows hang off `dw_account` and nothing here says what
    // should happen to them, because that is how a stand once lost every
    // survey answer behind its profiles on the first deletion.
    onAccountDeleting: (ctx, accountId) async {
      // Nothing to do: the profile goes with the account, and it is all
      // there is. The moment something else points at the profile — a
      // message, an order, a review someone else reads — this is where the
      // project decides, and the answer is usually a tombstone rather than a
      // deletion.
    },
    //
    // When something else does point at the profile, there are two honest
    // answers, and the project picks one per kind of row:
    //
    //  * delete it, when it is about that person alone (their own drafts, their
    //    settings, their files);
    //  * keep it and empty the profile instead — a **tombstone**: the row stays
    //    with a `deleted_at` and no name, phone or photo, `account_id` nulled by
    //    `ON DELETE SET NULL`, so other people's content keeps an author and the
    //    screens say "member who left". The example does exactly this, in
    //    `example/dartway_example_server/lib/src/example_auth.dart`.
    //
    // What may not be done is hiding the person behind a flag and keeping their
    // name and phone: that is a deletion the law does not accept and the member
    // was not told about. Whichever route the project takes, the app says which
    // one before it asks the member to confirm.
    resendDelay: resendDelay,
  );

  static Future<void> _logCode(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    String code,
  ) async => stdout.writeln('Sign-in code for $identifier: $code');

  /// [accountId]'s fixed sign-in code, or `null` for an account without one
  /// or no account at all. Cached on [ctx]: `generateCode` and `deliverCode`
  /// both ask in the same request, and it is one query either way.
  static Future<String?> _testCode(DwCallContext ctx, int? accountId) =>
      ctx.memo(#appAuthTestCode, () async {
        if (accountId == null) return null;
        final profile = await ctx.db.userProfiles.findFirst(
          where: (t) => t.accountId.equals(accountId),
        );
        return profile?.testVerificationCode;
      });

  /// The profile a new account starts with, in the account's transaction.
  ///
  /// A sign-up is refused, and nothing is created, while sign-up is switched off
  /// in the settings ([DartwayStarterRefusal.signUpClosed]) or without the terms
  /// accepted ([DartwayStarterRefusal.consentsRequired]) — the app then asks for
  /// them and verifies the same code again. An account made by a tool
  /// ([DwToolOrigin]: the admin bootstrap, the dev seed) accepts nothing on
  /// anyone's behalf: its `termsAcceptedAt` stays empty.
  static Future<UserProfileRow> createProfile(
    DwCallContext ctx,
    int accountId,
    DwAccountOrigin origin,
  ) async {
    final now = DateTime.now().toUtc();
    switch (origin) {
      case DwSignInOrigin(:final registration):
        if (!await AppAuth.isSignUpEnabled(ctx.db)) {
          ctx.refuse(DartwayStarterRefusal.signUpClosed, field: 'identifier');
        }
        if (registration[RegistrationKeys.terms] != 'true') {
          ctx.refuse(DartwayStarterRefusal.consentsRequired, field: 'consents');
        }
        return ctx.db.userProfiles.insert(
          UserProfileRow(
            accountId: accountId,
            firstName: registration[RegistrationKeys.firstName]?.trim() ?? '',
            agreedForMarketing:
                registration[RegistrationKeys.marketing] == 'true',
            termsAcceptedAt: now,
            createdAt: now,
          ),
        );
      case DwToolOrigin():
        return ctx.db.userProfiles.insert(
          UserProfileRow(accountId: accountId, createdAt: now),
        );
    }
  }

  /// Whether a new visitor may create an account: the `signUpEnabled` setting,
  /// on while nobody has stored it.
  static Future<bool> isSignUpEnabled(DwDatabaseHandle db) async {
    final row = await db.appSettings.findFirst(
      where: (t) => t.key.equals(AppSettingKeys.signUpEnabled),
    );
    return row?.value.trim().toLowerCase() != 'false';
  }
}
