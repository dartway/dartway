import 'dart:math';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../context/dw_call_context.dart';

final Random _codeRandom = Random.secure();

/// A random code of [length] digits — what `_requestCode` draws when
/// `DwAuthConfig.generateCode` is unset, or returns `null` for a call. A
/// project's own hook does not call this to fall back to the default: it
/// returns `null` and the framework does, with `codeLength`, so the two
/// cannot disagree. Exported anyway, for the rarer case of a project drawing
/// a code of the same shape somewhere `generateCode` is not — a one-off
/// support tool, say.
String dwRandomCode(int length) =>
    List.generate(length, (_) => _codeRandom.nextInt(10)).join();

/// Sign-in by one-time code, configured by the project.
///
/// The framework owns accounts, identities and session keys, the ticket, its
/// hash, its lifetime and the request limits; the project owns what an
/// identifier looks like ([normalize]), what code a request gets
/// ([generateCode]) and how that code reaches a person ([deliverCode]).
/// **The two are independent** (issue #310): the framework used to infer "do
/// not send" from "the code was not random" — a project whose fixed code also
/// had to be sent (SMS turned on for a default code out of its own settings,
/// say) had no way to say so without working around [deliverCode] entirely.
/// Now [generateCode] only picks the code, [deliverCode] always runs, and
/// "send nowhere" (a test account's fixed code, most often) is a decision
/// [deliverCode] makes for itself.
final class DwAuthConfig {
  const DwAuthConfig({
    required this.normalize,
    required this.deliverCode,
    required this.accountDeletion,
    this.generateCode,
    this.onAccountCreated,
    this.onIdentifierChanged,
    this.onAccountDeleting,
    this.onExternalAccountCreated,
    this.codeLength = 6,
    this.codeLifetime = const Duration(minutes: 10),
    this.maxAttempts = 5,
    this.maxRequestsPerWindow = 5,
    this.requestWindow = const Duration(minutes: 10),
    this.resendDelay = const Duration(seconds: 60),
    this.keyTouchInterval = const Duration(minutes: 10),
  }) : assert(codeLength >= 4 && codeLength <= 12),
       assert(maxAttempts > 0),
       assert(maxRequestsPerWindow > 0);

  /// The canonical form of an identifier (`+79991234567`, a lower-cased
  /// e-mail), or `null` when [raw] is not a valid identifier of [kind]
  /// (answered `dw.invalid` on field `identifier`).
  final String? Function(DwIdentifierKind kind, String raw) normalize;

  /// Called **always**, whatever [code] is — generated or returned by
  /// [generateCode]. Never log the code.
  ///
  /// Deciding not to send — a store reviewer's or a test account's fixed
  /// code, most often — is this hook's to make, by simply returning without
  /// sending anything; the framework no longer makes that decision for it by
  /// withholding the call.
  ///
  /// **Runs after the ticket's own transaction has committed, not inside
  /// it.** [DwCallContext.db] here is a fresh connection from the pool, not
  /// the one the ticket was written on — this hook may still use `ctx.db`
  /// (and `ctx.transaction` for one of its own, if it writes anything), but
  /// it is not the same transaction, and does not see writes from it that
  /// have not committed (which is none, since it has committed by the time
  /// this runs). The point of the split: a project's `deliverCode` is
  /// typically an HTTP call to a provider, and running it inside the
  /// ticket's transaction — under the identifier's advisory lock — would
  /// hold a pooled connection for as long as that call takes, which is how
  /// one slow provider empties the pool for every caller. **The ticket
  /// exists, and already counts against the limit, before this runs** — so
  /// throwing here (a provider timeout, say) does not undo it: the caller
  /// sees an incident (or a refusal, thrown as [DwRefusalException]) and
  /// waits out [resendDelay] for another attempt, the same as any resend.
  ///
  /// [accountId] is the account [identifier] already belongs to, or `null`
  /// for one no account has yet — the same value [generateCode] was asked
  /// with, so a hook that skips sending for an account's own fixed code can
  /// look that account up again the same way [generateCode] did, without the
  /// two having to agree through anything but this parameter. Looking it up
  /// twice is one lookup with `ctx.memo`.
  final Future<void> Function(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    String code,
    int? accountId,
  )
  deliverCode;

  /// The code this request gets, or `null` to draw [codeLength] random
  /// digits ([dwRandomCode]) — the same fallback whether [generateCode]
  /// itself is unset or is set and returns `null` for this call, so a hook
  /// that fixes the code for a few identifiers and leaves the rest to the
  /// framework does not have to call [dwRandomCode] itself, or hard-code a
  /// length that then disagrees with [codeLength]. A project returns a code
  /// of its own for a fixed one — a store reviewer, a test account, a
  /// default code out of its own settings — and [deliverCode] decides,
  /// independently, whether that code goes anywhere.
  ///
  /// Asked for sign-in codes (`DwRequestCode`) and for the codes of
  /// `DwRequestIdentifierCode` alike. [accountId] is the account [identifier]
  /// already belongs to, or `null` for one no account has yet — not the
  /// caller attaching it, which is `ctx.accountId` where that matters (an
  /// attach request only, `null` for a sign-in).
  final Future<String?> Function(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    int? accountId,
  )?
  generateCode;

  /// Runs in the transaction that creates an account for an identifier: the
  /// place to insert the project's profile. [origin] says who created it — a
  /// sign-in, with what the client sent with the code
  /// ([DwSignInOrigin.registration]), or a tool through
  /// `DwAccountService.ensure` ([DwToolOrigin]), which has accepted nothing
  /// on anyone's behalf.
  ///
  /// Refusing here refuses the sign-in, and nothing is created.
  final Future<void> Function(
    DwCallContext ctx,
    int accountId,
    DwIdentifierKind kind,
    String identifier,
    DwAccountOrigin origin,
  )?
  onAccountCreated;

  /// Runs in the transaction that changes an existing account's identifiers
  /// through the framework — `DwConfirmIdentifier`, and
  /// `DwAccountService.moveIdentities` / `removeIdentities` — once per account
  /// and identifier affected, after the change: the place to mirror an
  /// identifier into the project's own rows. Throwing (or refusing) undoes the
  /// change.
  ///
  /// Not called for the identity an account is created with
  /// ([onAccountCreated] sees it), nor when a sign-in merely confirms an
  /// identifier the account already has. The framework publishes nothing
  /// about identifiers; publishing is the hook's to do.
  final Future<void> Function(DwCallContext ctx, DwIdentifierChange change)?
  onIdentifierChanged;

  /// Runs in the transaction that creates an account for an identity an
  /// external provider proved (`google`, `apple` —
  /// `DwAccountService.signInWithExternalIdentity`), where
  /// [DwAuthConfig.onAccountCreated] runs for an identifier a code reached:
  /// the place to insert the project's profile from what the provider told
  /// about the person. [registration] is what the app sent with the sign-in.
  ///
  /// Required to sign in externally at all: without it such a sign-in throws,
  /// rather than leaving an account no project row belongs to.
  final Future<void> Function(
    DwCallContext ctx,
    int accountId,
    String provider,
    String subject,
    Map<String, String> registration,
  )?
  onExternalAccountCreated;

  /// Runs in the transaction that deletes an account (`DwDeleteMyAccount`,
  /// `DwAccountService.deleteAccount`), before the framework removes what it
  /// keeps: the place to delete — or anonymise — the project's rows of
  /// [accountId]. A row referencing `dw_account` without `ON DELETE CASCADE`
  /// must go here, or the deletion fails. Throwing (or refusing) keeps the
  /// account.
  final Future<void> Function(DwCallContext ctx, int accountId)?
  onAccountDeleting;

  /// Who may delete an account — required, because either default was wrong
  /// for someone. The framework used to answer `DwDeleteMyAccount` for every
  /// project, and two of them learned it had become live only when a pin
  /// moved; each then refused it from [onAccountDeleting], which also refused
  /// the operator's own deletions.
  final DwAccountDeletion accountDeletion;

  /// Digits in a delivered code.
  final int codeLength;
  final Duration codeLifetime;

  /// Wrong codes accepted per ticket before it is dead.
  final int maxAttempts;

  /// Code requests per identifier within [requestWindow].
  final int maxRequestsPerWindow;
  final Duration requestWindow;

  /// Minimum time between two code requests for one identifier; announced to
  /// the client as `DwCodeTicket.resendAfter` and enforced.
  final Duration resendDelay;

  /// `last_used_at` of a session key is written at most once per this
  /// interval, not on every call.
  final Duration keyTouchInterval;
}

/// Who created an account: the argument of `DwAuthConfig.onAccountCreated`.
sealed class DwAccountOrigin {
  const DwAccountOrigin();

  /// A sign-in by one-time code to an identifier without an account.
  const factory DwAccountOrigin.signIn(Map<String, String> registration) =
      DwSignInOrigin;

  /// `DwAccountService.ensure`: a seed, an admin bootstrap, an import.
  const factory DwAccountOrigin.tool() = DwToolOrigin;
}

/// An account created by signing in.
final class DwSignInOrigin extends DwAccountOrigin {
  const DwSignInOrigin(this.registration);

  /// What the client sent with the code (`DwVerifyCode.registration`) — the
  /// project's sign-up fields; empty when it sent none.
  final Map<String, String> registration;

  @override
  String toString() => 'DwSignInOrigin(${registration.keys.join(', ')})';
}

/// An account created by `DwAccountService.ensure`, outside any sign-in.
final class DwToolOrigin extends DwAccountOrigin {
  const DwToolOrigin();

  @override
  String toString() => 'DwToolOrigin()';
}

/// Why an account's identifiers changed.
enum DwIdentifierChangeCause {
  /// The account's owner confirmed a code (`DwConfirmIdentifier`).
  confirmed,

  /// `DwAccountService.moveIdentities` moved it between accounts.
  moved,

  /// `DwAccountService.removeIdentities` removed it.
  removed,
}

/// One identifier of one account changed: the argument of
/// `DwAuthConfig.onIdentifierChanged`.
///
/// [previous] is the value the account had and [current] the value it has:
/// an attached identifier has no [previous], a removed one no [current], a
/// replaced one both. A move is two changes — removed from the account it
/// left, attached to the account it joined.
final class DwIdentifierChange {
  const DwIdentifierChange({
    required this.accountId,
    required this.kind,
    required this.cause,
    this.previous,
    this.current,
  }) : assert(previous != null || current != null);

  final int accountId;
  final DwIdentifierKind kind;
  final DwIdentifierChangeCause cause;
  final String? previous;
  final String? current;

  /// Without the values: an identifier is personal data, and a change is the
  /// kind of thing that ends up in a log line.
  @override
  String toString() =>
      'DwIdentifierChange(account $accountId, ${kind.name}, ${cause.name})';
}

/// Who may delete an account ([DwAuthConfig.accountDeletion]).
enum DwAccountDeletion {
  /// A signed-in member deletes their own account with `DwDeleteMyAccount` —
  /// what an app store asks of an app people sign up in.
  byMember,

  /// Only server code deletes accounts (`ctx.accounts.deleteAccount`);
  /// `DwDeleteMyAccount` is refused `dw.forbidden`.
  byOperator,
}
