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
  final Future<String?> Function(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String identifier,
    int? accountId,
  )?
  fixedCode;

  /// Runs in the sign-in transaction when an identifier gets a new account:
  /// the place to insert the project's profile. [registration] is what the
  /// client sent with the code.
  final Future<void> Function(
    DwCallContext ctx,
    int accountId,
    DwIdentifierKind kind,
    String identifier,
    Map<String, String> registration,
  )?
  onAccountCreated;

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
