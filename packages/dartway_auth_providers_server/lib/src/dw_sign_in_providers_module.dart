import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'dw_id_token_check.dart';
import 'dw_jwks_cache.dart';
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
  String get namespace => 'dw_auth_providers';

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
      case DwTokenAccepted(:final subject, :final claims):
        return ctx.accounts.signInWithExternalIdentity(
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
    }
  }

  @override
  List<String> problems(DwWireProtocol protocol) => [
    if (!protocol.knows(DwSignInWithProvider))
      'sign-in providers: the protocol does not register '
          'DwSignInWithProvider — build it as '
          'DwWireProtocol(dwAuthProvidersProtocolEntries, include: appProtocol)',
  ];
}
