import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../context/dw_call_context.dart';

/// Sign-in by one-time code, configured by the project.
///
/// The framework owns accounts, identities and session keys; the project owns
/// what an identifier looks like ([normalize]), how a code reaches a person
/// ([deliverCode]) and what an account means to it ([onAccountCreated]).
final class DwAuthConfig {
  const DwAuthConfig({
    required this.normalize,
    required this.deliverCode,
    this.fixedCode,
    this.onAccountCreated,
    this.onIdentifierChanged,
    this.onAccountDeleting,
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

  /// Sends [code] to [identifier]. Runs inside the transaction that records
  /// the ticket: when delivery throws, no ticket exists and the request does
  /// not count against the limit. Never log the code.
  ///
  /// Called for sign-in codes (`DwRequestCode`, `ctx.accountId` is `null`)
  /// and for codes confirming an identifier a signed-in account attaches
  /// (`DwRequestIdentifierCode`, `ctx.accountId` is that account) — the place
  /// to word the two messages differently.
  final Future<void> Function(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    String code,
  )
  deliverCode;

  /// A code that is accepted instead of a delivered one — for store reviewers
  /// and test accounts. [accountId] is the account the identifier belongs to,
  /// or `null`. Returning a code skips delivery.
  ///
  /// Asked for sign-in codes and for the codes of `DwRequestIdentifierCode`
  /// alike; in the second case `ctx.accountId` is the signed-in caller
  /// attaching the identifier (it is `null` for a sign-in), as it is in
  /// [deliverCode].
  final Future<String?> Function(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    int? accountId,
  )?
  fixedCode;

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

  /// Runs in the transaction that deletes an account (`DwDeleteMyAccount`,
  /// `DwAccountService.deleteAccount`), before the framework removes what it
  /// keeps: the place to delete — or anonymise — the project's rows of
  /// [accountId]. A row referencing `dw_account` without `ON DELETE CASCADE`
  /// must go here, or the deletion fails. Throwing (or refusing) keeps the
  /// account.
  final Future<void> Function(DwCallContext ctx, int accountId)?
  onAccountDeleting;

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
