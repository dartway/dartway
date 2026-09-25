import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'dw_id_token_check.dart';
import 'dw_jwks_cache.dart';
import 'dw_provider_tokens_migrations.dart';
import 'dw_sign_in_providers.dart';

/// Sign in with Google and Apple on a DartWay server.
///
/// ```dart
/// DwAppServer(
///   modules: [
///     DwSignInProvidersModule([
///       DwGoogleSignIn(clientIds: [androidClientId, iosClientId, webClientId]),
///       DwAppleSignIn(clientIds: ['com.club.app']),
///     ]),
///   ],
///   auth: DwAuthConfig(
///     ...,
///     onExternalAccountCreated: (ctx, accountId, provider, subject, data) =>
///         AppAuth.createProfile(ctx, accountId, data),
///   ),
/// );
/// ```
///
/// It brings one handler — `DwSignInWithProvider` — which verifies the
/// provider's token against the keys the provider publishes and signs in the
/// account of the subject it proves, creating one the first time. The
/// providers are independent: a project declares the ones it offers, and a
/// token of a provider it did not declare is refused like any other door this
/// server does not have.
///
/// Nothing of the token is stored. What is kept is the identity
/// (`dw_identity`, kind `google` or `apple`, value the provider's subject id)
/// and whatever the project's own hook writes.
final class DwSignInProvidersModule extends DwServerModule {
  DwSignInProvidersModule(List<DwSignInProvider> providers)
    : providers = {for (final setup in providers) setup.provider: setup} {
      if (providers.isEmpty) {
        throw ArgumentError.value(
          providers,
          'providers',
          'a module with no provider opens no door; leave it out instead',
        );
      }
      if (this.providers.length != providers.length) {
        throw ArgumentError.value(
          providers,
          'providers',
          'a provider is configured twice',
        );
      }
    }

  final Map<DwAuthProvider, DwSignInProvider> providers;

  @override
  String get namespace => dwAuthProvidersNamespace;

  /// The job that gives a person's refresh token back to Apple. It runs
  /// outside the deleting transaction on purpose: the account goes whether or
  /// not Apple is answering right now, and the revocation retries until it
  /// does.
  /// Revokes an Apple refresh token after its account is deleted.
  static const DwJobKind<({String provider, String clientId, String refreshToken})>
  revokeJob = DwJobKind(
    'dw.auth_providers.revoke',
    encode: _encodeRevocation,
    decode: _decodeRevocation,
  );

  static Map<String, Object?> _encodeRevocation(_Revocation r) => {
    'provider': r.provider,
    'clientId': r.clientId,
    'refreshToken': r.refreshToken,
  };

  static _Revocation _decodeRevocation(Map<String, Object?> json) => (
    provider: json['provider']! as String,
    clientId: json['clientId']! as String,
    refreshToken: json['refreshToken']! as String,
  );

  @override
  List<DwDatabaseMigration> get migrations => dwAuthProvidersMigrations;

  @override
  late final List<DwJobDefinition> jobs = [
    DwQueuedJob(
      revokeJob,
      // It calls Apple: never from inside the transaction that claimed it.
      transactional: false,
      maxAttempts: 8,
      handle: _revoke,
    ),
  ];

  @override
  late final List<DwCallHandler> handlers = [
    DwCallHandler.command<DwSignInWithProvider, DwAuthSession>(
      access: DwAccessRule.anonymous,
      // The answer carries a session token: a repeat of the call must mint a
      // new one, never be answered a stored one.
      recordsSuccess: false,
      handle: _signIn,
    ),
  ];

  Future<DwAuthSession> _signIn(
    DwCallContext ctx,
    DwSignInWithProvider command,
  ) async {
    final setup = providers[command.provider];
    if (setup == null) {
      ctx.log.warning(
        'sign-in with ${command.provider.name} refused: this server '
        'configures ${providers.keys.map((p) => p.name).join(', ')}',
      );
      ctx.refuse(DwCoreRefusal.forbidden, field: 'provider');
    }
    final DwTokenVerdict verdict;
    try {
      verdict = await DwIdTokenCheck(
        setup,
        now: DateTime.now().toUtc(),
      ).run(command.idToken, nonce: command.nonce);
    } on DwJwksUnavailable catch (error) {
      // Nothing is wrong with the token, and saying "rejected" would send the
      // app to ask the provider for another one it cannot check either.
      ctx.log.error('${command.provider.name} sign-in: $error');
      ctx.refuse(DwProviderRefusal.providerUnreachable, field: 'provider');
    }
    switch (verdict) {
      case DwTokenRejected(:final reason):
        // The log carries what was wrong; the app is told only that the
        // credential was not accepted.
        ctx.log.warning(
          '${command.provider.name} sign-in refused: $reason',
        );
        ctx.refuse(DwProviderRefusal.credentialRejected, field: 'idToken');
      case DwTokenAccepted(:final subject, :final claims, :final clientId):
        final session = await ctx.accounts.signInWithExternalIdentity(
          provider: command.provider.name,
          subject: subject,
          // The app's own words, minus anything it wrote under the server's
          // prefix, and then the claims the provider signed: a project
          // reading `dw.email` reads a verified e-mail, not a typed one.
          registration: {
            for (final MapEntry(:key, :value) in command.registration.entries)
              if (!key.startsWith(DwProviderClaim.prefix)) key: value,
            ...claims,
          },
        );
        await _keepRefreshToken(
          ctx,
          setup,
          accountId: session.id,
          subject: subject,
          clientId: clientId,
          code: command.authorizationCode,
        );
        return session;
    }
  }

  /// Exchanges Apple's one-time authorization code for the refresh token that
  /// can later revoke this person's tokens, and keeps it.
  ///
  /// A failure here never fails the sign-in: the person is already proved by
  /// the identity token, and being unable to store something for a deletion
  /// that may never come is no reason to turn them away. It is logged as a
  /// warning, because an app that offers Sign in with Apple owes Apple that
  /// revocation.
  Future<void> _keepRefreshToken(
    DwCallContext ctx,
    DwSignInProvider setup, {
    required int accountId,
    required String subject,
    required String clientId,
    required String? code,
  }) async {
    if (setup is! DwAppleSignIn || code == null || code.isEmpty) return;
    final signingKey = setup.signingKey;
    if (signingKey == null) {
      ctx.log.warning(
        'Apple sign-in: the app sent an authorization code and this server '
        'has no signing key, so nothing can revoke this person\'s tokens when '
        'they delete their account (DwAppleSignIn.signingKey)',
      );
      return;
    }
    try {
      final refreshToken = await setup.endpoint.refreshTokenFor(
        code: code,
        clientId: clientId,
        clientSecret: signingKey.mintFor(clientId),
      );
      if (refreshToken == null) {
        ctx.log.warning('Apple sign-in: no refresh token in the exchange');
        return;
      }
      await ctx.db.execute(
        'INSERT INTO dw_provider_token '
        '(account_id, provider, subject, client_id, refresh_token, updated_at) '
        'VALUES (@account, @provider, @subject, @client, @token, now()) '
        'ON CONFLICT (account_id, provider) DO UPDATE SET '
        'subject = @subject, client_id = @client, refresh_token = @token, '
        'updated_at = now()',
        params: {
          'account': accountId,
          'provider': DwAuthProvider.apple.name,
          'subject': subject,
          'client': clientId,
          'token': refreshToken,
        },
      );
    } on Object catch (error) {
      ctx.log.warning('Apple sign-in: the code was not exchanged: $error');
    }
  }

  /// What deleting an account owes a person who signed in with a provider:
  /// the app tells the provider it is no longer theirs.
  ///
  /// The token is handed to a job rather than sent from here — the deletion
  /// must not wait on Apple, and must not fail because Apple is down — and
  /// the row goes with the account either way.
  @override
  Future<void> accountDeleting(DwCallContext ctx, int accountId) async {
    final rows = await ctx.db.query(
      'SELECT provider, client_id, refresh_token FROM dw_provider_token '
      'WHERE account_id = @id',
      params: {'id': accountId},
    );
    for (final row in rows) {
      await ctx.jobs.enqueue(revokeJob, (
        provider: row.get<String>('provider'),
        clientId: row.get<String>('client_id'),
        refreshToken: row.get<String>('refresh_token'),
      ));
    }
    await ctx.db.execute(
      'DELETE FROM dw_provider_token WHERE account_id = @id',
      params: {'id': accountId},
    );
  }

  Future<void> _revoke(DwCallContext ctx, _Revocation revocation) async {
    final setup = providers[DwAuthProvider.values.firstWhere(
      (p) => p.name == revocation.provider,
      orElse: () => DwAuthProvider.apple,
    )];
    final (:clientId, :refreshToken, provider: _) = revocation;
    if (setup is! DwAppleSignIn) {
      // The provider was reconfigured away between the deletion and this run;
      // there is nobody to tell, and retrying will not change that.
      ctx.log.warning('$revokeJob: no Apple provider configured any more');
      return;
    }
    final signingKey = setup.signingKey;
    if (signingKey == null) {
      ctx.log.warning('$revokeJob: no signing key to speak to Apple with');
      return;
    }
    await setup.endpoint.revoke(
      refreshToken: refreshToken,
      clientId: clientId,
      clientSecret: signingKey.mintFor(clientId),
    );
  }

  @override
  List<String> problems(DwWireProtocol protocol) => [
    if (!protocol.knows(DwSignInWithProvider))
      'sign-in providers: the protocol does not register '
          'DwSignInWithProvider — build it as '
          'DwWireProtocol(dwAuthProvidersProtocolEntries, include: appProtocol)',
  ];
}

/// What `revokeJob` carries: the refresh token to revoke, and where.
typedef _Revocation = ({String provider, String clientId, String refreshToken});
