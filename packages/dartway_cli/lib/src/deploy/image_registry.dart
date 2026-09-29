import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Whether a pinned image tag can still be pulled from its registry —
/// anonymously, the way every image this stack pins is meant to be pulled.
///
/// Checked here, ahead of `deploy run`, because the alternative is finding out
/// at `docker compose up`: the images the compose file *builds* (server, web)
/// fail fast in the "Build images" step, but a base image it only *pulls*
/// (Postgres, nginx, certbot, the bundled storage and its init image) is not
/// touched until the step that starts it — for the bundled storage, well past
/// half the run (D-094, dartway/dartway#331: a pinned storage image was
/// pulled from three registries for months after every one of them had
/// stopped serving the tag).
///
/// A HEAD of the manifest, with the anonymous bearer token the registry's own
/// `WWW-Authenticate` challenge asks for — the same two-step handshake
/// `docker pull` performs, without pulling a single layer.
class DwImageRegistry {
  DwImageRegistry({
    this.connectTo,
    this.scheme = 'https',
    this.timeout = const Duration(seconds: 10),
  });

  /// Where to open connections instead of resolving the registry (and token)
  /// host — for tests, which stand in for both behind one local server and
  /// branch on the `Host` header, exactly as `DwOutsideProbe` does for a
  /// deployed site. Null in production: DNS answers, as it does for everyone.
  final ({String host, int port})? connectTo;

  /// `https` in production; tests set `http`, since a redirected socket
  /// cannot complete a TLS handshake for a host it does not hold a
  /// certificate for.
  final String scheme;

  final Duration timeout;

  HttpClient _client() {
    final client = HttpClient()..connectionTimeout = timeout;
    final redirect = connectTo;
    if (redirect != null) {
      client.connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(redirect.host, redirect.port);
    }
    return client;
  }

  /// Resolves [image] against the Docker Registry HTTP API v2.
  ///
  /// [DwImageResolution.transient] separates "the registry could not be
  /// asked right now" (no route, a timeout, a rate limit, a 5xx of its own)
  /// from "the registry answered, and the answer is no" (401 it cannot
  /// satisfy, 404) — the first is a network hiccup this machine had, not a
  /// fact about the image, and `deploy check` reports it as a note rather
  /// than failing the deploy over its own flaky connection.
  Future<DwImageResolution> resolve(String image) async {
    final ref = DwImageRef.parse(image);
    final client = _client();
    try {
      final manifestUrl = Uri(
        scheme: scheme,
        host: ref.registryHost,
        path: '/v2/${ref.repository}/manifests/${ref.tag}',
      );
      var response = await _head(client, manifestUrl, null);
      if (response.statusCode == 401) {
        final challenge = response.headers.value('www-authenticate');
        final token = challenge == null ? null : await _token(client, challenge);
        if (token == null) {
          return DwImageResolution.fail(
            '${ref.registryHost} demands authentication this check cannot '
            'satisfy${challenge == null ? '' : ': $challenge'}',
          );
        }
        response = await _head(client, manifestUrl, token);
      }
      switch (response.statusCode) {
        case 200:
          // A genuine manifest answer names its own digest; a 200 without
          // one is not a manifest — some page a misconfigured mirror or a
          // captive portal served instead, which a followed redirect would
          // otherwise have handed back indistinguishably from the real
          // thing (redirects are not followed here for exactly this reason).
          final digest = response.headers.value('docker-content-digest');
          if (digest == null) {
            return DwImageResolution.fail(
              '${ref.registryHost} answered 200 with no Docker-Content-Digest '
              '— not a manifest, so not treated as one',
            );
          }
          return DwImageResolution.ok('resolves at ${ref.registryHost}');
        case 404:
          return DwImageResolution.fail(
            '${ref.repository}:${ref.tag} not found at ${ref.registryHost} '
            '(404) — the tag was removed or the repository is gone',
          );
        case 401:
          // The second HEAD, with a token the registry's own challenge
          // handed out, still refused: a real wall, not a missing token.
          return DwImageResolution.fail(
            '${ref.registryHost} refused the anonymous token it issued '
            'itself (401) — the image needs credentials this check does not '
            'have',
          );
        case 429:
          return DwImageResolution.transient(
            '${ref.registryHost} is rate-limiting anonymous pulls right now '
            '(429)',
          );
        case final status when status >= 500:
          return DwImageResolution.transient(
            '${ref.registryHost} answered $status — its own trouble, not '
            "the image's",
          );
        case final status:
          return DwImageResolution.fail('${ref.registryHost} answered $status');
      }
    } on SocketException catch (error) {
      return DwImageResolution.transient(
        'could not reach ${ref.registryHost}: ${error.message}',
      );
    } on TimeoutException {
      return DwImageResolution.transient(
        '${ref.registryHost} did not answer within $timeout',
      );
    } on HandshakeException catch (error) {
      return DwImageResolution.transient(
        'TLS handshake with ${ref.registryHost} failed: ${error.message}',
      );
    } on TlsException catch (error) {
      return DwImageResolution.transient(
        'TLS with ${ref.registryHost} failed: ${error.message}',
      );
    } on HttpException catch (error) {
      return DwImageResolution.transient(
        '${ref.registryHost} sent a malformed HTTP response: '
        '${error.message}',
      );
    } on FormatException catch (error) {
      // Only reachable from decoding the token endpoint's body in [_token] —
      // a registry that answers its own token realm with something that is
      // not JSON is this machine's bad luck right now, not proof the image
      // is gone.
      return DwImageResolution.transient(
        '${ref.registryHost}\'s token endpoint answered something this '
        'check could not parse: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _head(
    HttpClient client,
    Uri url,
    String? token,
  ) async {
    final request = await client.headUrl(url).timeout(timeout);
    // Not followed: a redirect to whatever a misconfigured mirror or a
    // captive portal serves at the far end would otherwise come back
    // indistinguishable from a genuine 200 — the Docker-Content-Digest check
    // in [resolve] is the second half of the same guard.
    request.followRedirects = false;
    request.headers.set(
      'accept',
      'application/vnd.docker.distribution.manifest.v2+json, '
          'application/vnd.docker.distribution.manifest.list.v2+json, '
          'application/vnd.oci.image.manifest.v1+json, '
          'application/vnd.oci.image.index.v1+json',
    );
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    return request.close().timeout(timeout);
  }

  /// A `WWW-Authenticate: Bearer realm="...",service="...",scope="..."`
  /// challenge, turned into the anonymous token it asks for.
  Future<String?> _token(HttpClient client, String challenge) async {
    final match = RegExp(
      r'^Bearer\s+(.*)$',
      caseSensitive: false,
    ).firstMatch(challenge.trim());
    if (match == null) return null;
    final params = <String, String>{
      for (final part in RegExp(
        r'(\w+)="([^"]*)"',
      ).allMatches(match.group(1)!))
        part.group(1)!: part.group(2)!,
    };
    final realm = params['realm'];
    if (realm == null) return null;
    final query = {
      if (params['service'] case final service?) 'service': service,
      if (params['scope'] case final scope?) 'scope': scope,
    };
    final tokenUrl = Uri.parse(
      realm,
    ).replace(queryParameters: query.isEmpty ? null : query);
    final request = await client.getUrl(tokenUrl).timeout(timeout);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body);
    if (json is Map<String, Object?>) {
      final token = json['token'] ?? json['access_token'];
      return token is String ? token : null;
    }
    return null;
  }
}

/// Whether [DwImageRegistry.resolve] answered a real question about the
/// image, or could not ask it right now.
///
/// [ok] true is the only "the tag is there" answer; [ok] false with
/// [transient] false is a definite "it is not" (or "it demands credentials
/// this check will never have"); [transient] true is neither — the registry
/// was not reachable, or answered with its own trouble, and asking again
/// later might answer differently.
class DwImageResolution {
  const DwImageResolution.ok(this.detail) : ok = true, transient = false;
  const DwImageResolution.fail(this.detail) : ok = false, transient = false;
  const DwImageResolution.transient(this.detail) : ok = false, transient = true;

  final bool ok;
  final bool transient;
  final String detail;
}

/// `[registry-host/]repository:tag`, split the way `docker pull` reads it.
///
/// `library/<name>` for a bare repository name is a rule of Docker Hub's own
/// naming, not of the reference syntax: it applies when there is no explicit
/// registry host, and equally when the host explicitly names Docker Hub
/// itself (`docker.io`, `index.docker.io` — both normalised to the API's own
/// `registry-1.docker.io`), because those are the cases a bare name means
/// "the default registry's official image". A bare name after any *other*
/// explicit host — `mirror.gcr.io/postgres`, mirroring the exact reference
/// the renderer put in the compose file (see [DwStack.pinnedImages]) — names
/// a repository called `postgres` on that host, not `library/postgres`: no
/// other registry recognises the rewrite, and neither does Docker's own
/// reference parser.
class DwImageRef {
  const DwImageRef({
    required this.registryHost,
    required this.repository,
    required this.tag,
  });

  final String registryHost;
  final String repository;
  final String tag;

    /// Hosts that name Docker Hub explicitly rather than by leaving the host
  /// out — `docker pull docker.io/postgres` and `docker pull postgres` name
  /// the same image, and both take the `library/` rule; only a *different*
  /// registry does not.
  static const _dockerHubHosts = {'docker.io', 'index.docker.io'};

  static DwImageRef parse(String image) {
    final firstSlash = image.indexOf('/');
    String rest = image;
    String? explicitHost;
    if (firstSlash != -1) {
      final firstSegment = image.substring(0, firstSlash);
      if (firstSegment.contains('.') ||
          firstSegment.contains(':') ||
          firstSegment == 'localhost') {
        explicitHost = firstSegment;
        rest = image.substring(firstSlash + 1);
      }
    }
    final isDockerHub = explicitHost == null || _dockerHubHosts.contains(explicitHost);
    final tagColon = rest.lastIndexOf(':');
    final repoNoTag = tagColon == -1 ? rest : rest.substring(0, tagColon);
    final tag = tagColon == -1 ? 'latest' : rest.substring(tagColon + 1);
    final repository = repoNoTag.contains('/') || !isDockerHub
        ? repoNoTag
        : 'library/$repoNoTag';
    return DwImageRef(
      registryHost: isDockerHub ? 'registry-1.docker.io' : explicitHost,
      repository: repository,
      tag: tag,
    );
  }
}
