import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/alerts/dw_proxy_settings.dart';
import 'package:test/test.dart';

/// The proxy URL is read once, at boot, on a production machine nobody attaches
/// a debugger to — and what it produces decides whether alerts arrive at all.
/// These are the four shapes that reach it.
void main() {
  group('DwProxySettings.parse', () {
    test('reads host, port and credentials', () {
      final settings = DwProxySettings.parse('http://bob:s3cret@10.0.0.5:3128');

      expect(settings, isNotNull);
      expect(settings!.host, '10.0.0.5');
      expect(settings.port, 3128);
      expect(settings.username, 'bob');
      expect(settings.password, 's3cret');
      expect(settings.hasCredentials, isTrue);
      expect(settings.proxyConfiguration, 'PROXY 10.0.0.5:3128');
    });

    test('percent-encoded credentials arrive decoded', () {
      // A password with a `@` or a `:` has to be encoded to survive the URL —
      // sent on literally, the proxy would refuse every alert.
      final settings = DwProxySettings.parse(
        'http://bob%40corp:p%40ss%3Aword@proxy.example.com:8080',
      );

      expect(settings!.username, 'bob@corp');
      expect(settings.password, 'p@ss:word');
    });

    test('reads a proxy without credentials', () {
      final settings = DwProxySettings.parse('http://proxy.example.com:8080');

      expect(settings, isNotNull);
      expect(settings!.host, 'proxy.example.com');
      expect(settings.port, 8080);
      expect(settings.username, isNull);
      expect(settings.password, isNull);
      expect(settings.hasCredentials, isFalse);
    });

    test('falls back to the scheme port when none is stated', () {
      expect(DwProxySettings.parse('http://proxy.example.com')?.port, 80);
      expect(DwProxySettings.parse('https://proxy.example.com')?.port, 443);
    });

    test('a blank or missing value is no proxy, and says nothing', () {
      final complaints = <String>[];

      expect(DwProxySettings.parse(null, logFunction: complaints.add), isNull);
      expect(DwProxySettings.parse('', logFunction: complaints.add), isNull);
      expect(DwProxySettings.parse('   ', logFunction: complaints.add), isNull);

      // Not configuring a proxy is the normal case, not a misconfiguration.
      expect(complaints, isEmpty);
    });

    test('junk is refused audibly rather than guessed at', () {
      for (final junk in [
        'proxy.example.com:3128', // no scheme — the commonest typo
        'socks5://proxy.example.com:1080', // not an HTTP proxy
        'http://', // no host
        'not a url at all',
        'http://bob:secret@', // credentials, nothing to connect to
        'http://:secret@proxy.example.com:3128', // no user name
      ]) {
        final complaints = <String>[];

        expect(
          DwProxySettings.parse(junk, logFunction: complaints.add),
          isNull,
          reason: 'expected "$junk" to be refused',
        );
        expect(complaints, hasLength(1), reason: 'silent about "$junk"');
      }
    });

    test('an undecodable escape is junk, not a crash at boot', () {
      final complaints = <String>[];

      expect(
        DwProxySettings.parse(
          'http://bob:%C3%28@proxy.example.com:3128',
          logFunction: complaints.add,
        ),
        isNull,
      );
      expect(complaints, hasLength(1));
    });

    test('a lone percent sign is taken literally, the way a URL reads it', () {
      // `Uri.parse` escapes it to `%25` before we ever see it, so `50%` is a
      // password of three characters rather than a refused config.
      expect(
        DwProxySettings.parse('http://bob:50%@proxy.example.com:3128')?.password,
        '50%',
      );
    });
  });

  group('DwProxyHttpClient.fromEnv', () {
    test('no key at all means direct access, exactly as before', () {
      expect(DwProxyHttpClient.fromEnv(env: const {}), isNull);
    });

    test('a blank key means direct access', () {
      expect(
        DwProxyHttpClient.fromEnv(
          env: const {DwTelegramAlertsKeys.dwTelegramAlertsProxyUrlKey: '  '},
        ),
        isNull,
      );
    });

    test('junk degrades to direct access instead of failing the boot', () {
      final complaints = <String>[];

      expect(
        DwProxyHttpClient.fromEnv(
          env: const {
            DwTelegramAlertsKeys.dwTelegramAlertsProxyUrlKey: 'nonsense',
          },
          logFunction: complaints.add,
        ),
        isNull,
      );
      expect(complaints, hasLength(1));
    });

    test('a proxy URL builds a client', () {
      final client = DwProxyHttpClient.fromEnv(
        env: const {
          DwTelegramAlertsKeys.dwTelegramAlertsProxyUrlKey:
              'http://bob:s3cret@10.0.0.5:3128',
        },
      );

      expect(client, isNotNull);
      client!.close();
    });
  });
}
