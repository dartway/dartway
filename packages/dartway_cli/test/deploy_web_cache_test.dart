import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/serverpod_config.dart';
import 'package:dartway_cli/src/deploy/web_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The configuration the template ships, and the two ways of getting it wrong
/// that this whole file exists for: a rule that says "immutable" over a name a
/// Flutter build reuses, and a configuration that says nothing at all.
const String _shippedConfiguration = '''
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;
  etag on;

  location / {
    try_files \$uri \$uri/ /index.html;
    add_header Cache-Control "no-cache";
  }

  location ~* "\\.[0-9a-f]{8,}\\.(js|css|wasm|json|png|jpe?g|gif|svg|webp|avif|ico|woff2?|otf|ttf)\$" {
    add_header Cache-Control "public, max-age=31536000, immutable";
  }
}
''';

/// The rule as projects keep writing it: correct for a bundler that
/// fingerprints, wrong for a build that does not.
const String _immutableAssetsConfiguration = '''
server {
  listen 80;
  root /usr/share/nginx/html;

  location / {
    try_files \$uri \$uri/ /index.html;
  }

  location ~* \\.(png|jpg|jpeg|gif|ico|svg|woff|woff2)\$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  location ~* \\.(js|css|json|wasm)\$ {
    expires 30d;
  }
}
''';

void main() {
  group('cache-control reading', () {
    test('no-cache and friends mean the copy has to be confirmed', () {
      for (final value in [
        'no-cache',
        'no-store',
        'public, must-revalidate',
        'max-age=0',
        'private, max-age=0, must-revalidate',
      ]) {
        expect(
          dwCacheReuse(cacheControl: value),
          DwCacheReuse.revalidated,
          reason: value,
        );
      }
    });

    test('a positive max-age or "immutable" means it is reused unasked', () {
      for (final value in [
        'public, max-age=2592000',
        'max-age=31536000, immutable',
        'public, max-age=31536000',
      ]) {
        expect(
          dwCacheReuse(cacheControl: value),
          DwCacheReuse.freely,
          reason: value,
        );
      }
    });

    // "immutable" beside a zero max-age is a contradiction someone wrote by
    // hand; the permissive half is the one a browser can act on.
    test('immutable wins over anything softer beside it', () {
      expect(
        dwCacheReuse(cacheControl: 'no-cache, immutable'),
        DwCacheReuse.freely,
      );
    });

    test('s-maxage alone is about a shared cache, not this browser', () {
      expect(dwCacheReuse(cacheControl: 's-maxage=600'), DwCacheReuse.unstated);
    });

    test('nothing said is its own answer', () {
      expect(dwCacheReuse(), DwCacheReuse.unstated);
      expect(dwCacheReuse(cacheControl: '  '), DwCacheReuse.unstated);
    });

    test('nginx "expires" is read as the Cache-Control it becomes', () {
      expect(dwCacheReuse(expires: '1y'), DwCacheReuse.freely);
      expect(dwCacheReuse(expires: '30d'), DwCacheReuse.freely);
      expect(dwCacheReuse(expires: '-1'), DwCacheReuse.revalidated);
      expect(dwCacheReuse(expires: 'epoch'), DwCacheReuse.revalidated);
      expect(dwCacheReuse(expires: 'off'), DwCacheReuse.unstated);
    });

    // Both headers go out, and a browser may act on the permissive one.
    test('the permissive half of a contradictory pair decides', () {
      expect(
        dwCacheReuse(cacheControl: 'no-cache', expires: '1y'),
        DwCacheReuse.freely,
      );
    });
  });

  group('location matching', () {
    final locations = dwParseNginxLocations(_shippedConfiguration);

    test('the shipped configuration parses into its two blocks', () {
      expect(locations, hasLength(2));
      expect(locations.first.pattern, '/');
      expect(locations.last.isRegex, isTrue);
    });

    test('a quoted regex pattern survives its braces', () {
      expect(locations.last.pattern, contains('{8,}'));
    });

    test('a regex beats a prefix, as nginx has it', () {
      final chosen = dwLocationFor(locations, '/app.9f2b1c4e.js');
      expect(chosen!.isRegex, isTrue);
      expect(chosen.reuse, DwCacheReuse.freely);
    });

    test('an unhashed name falls through to the prefix block', () {
      final chosen = dwLocationFor(locations, '/main.dart.js');
      expect(chosen!.pattern, '/');
      expect(chosen.reuse, DwCacheReuse.revalidated);
    });

    test('an exact match wins outright', () {
      final withExact = dwParseNginxLocations('''
server {
  location / { add_header Cache-Control "public, max-age=600"; }
  location = /index.html { add_header Cache-Control "no-cache"; }
  location ~* \\.html\$ { add_header Cache-Control "public, max-age=99"; }
}
''');
      expect(
        dwLocationFor(withExact, '/index.html')!.reuse,
        DwCacheReuse.revalidated,
      );
    });

    test('a ^~ prefix stops the regexes from being consulted', () {
      final withCaret = dwParseNginxLocations('''
server {
  location ^~ /assets/ { add_header Cache-Control "no-cache"; }
  location ~* \\.png\$ { expires 1y; }
}
''');
      expect(
        dwLocationFor(withCaret, '/assets/logo.png')!.reuse,
        DwCacheReuse.revalidated,
      );
      expect(dwLocationFor(withCaret, '/logo.png')!.reuse, DwCacheReuse.freely);
    });

    test('the longest prefix wins among prefixes', () {
      final prefixes = dwParseNginxLocations('''
server {
  location / { add_header Cache-Control "no-cache"; }
  location /canvaskit/ { expires 1y; }
}
''');
      expect(
        dwLocationFor(prefixes, '/canvaskit/canvaskit.wasm')!.reuse,
        DwCacheReuse.freely,
      );
    });
  });

  group('entry-point policies', () {
    test('the shipped configuration revalidates every entry point', () {
      final policies = dwEntryPointPolicies(_shippedConfiguration);
      expect(policies, hasLength(dwFlutterEntryPoints.length));
      expect(
        policies.values.every((reuse) => reuse == DwCacheReuse.revalidated),
        isTrue,
        reason: policies.toString(),
      );
    });

    // The bug this file is named after: a rule that is right for a
    // fingerprinting bundler, applied to a build that fingerprints nothing.
    test('"immutable assets" lands on the files a build overwrites', () {
      final policies = dwEntryPointPolicies(_immutableAssetsConfiguration);
      final freely = policies.entries
          .where((entry) => entry.value == DwCacheReuse.freely)
          .map((entry) => entry.key)
          .toSet();
      expect(freely, contains('/main.dart.js'));
      expect(freely, contains('/flutter_bootstrap.js'));
      expect(freely, contains('/assets/assets/images/logo.png'));
      expect(freely, contains('/icons/Icon-192.png'));
      // And an extension the list happens to omit — `.otf` here — falls
      // through to a block that says nothing, which is the other half of why
      // hand-written rules of this shape are so hard to reason about.
      expect(
        policies['/assets/fonts/MaterialIcons-Regular.otf'],
        DwCacheReuse.unstated,
      );
      // index.html itself is untouched by both rules, which is exactly why the
      // failure is invisible: the shell reloads, the code it loads does not.
      expect(policies['/index.html'], DwCacheReuse.unstated);
    });

    test('a configuration with no cache rules states nothing', () {
      final policies = dwEntryPointPolicies('''
server {
  listen 80;
  location / { try_files \$uri \$uri/ /index.html; }
}
''');
      expect(
        policies.values.every((reuse) => reuse == DwCacheReuse.unstated),
        isTrue,
      );
    });

    test('every probed path is one of the declared entry points', () {
      expect(dwProbedEntryPoints, everyElement(isIn(dwFlutterEntryPoints)));
    });
  });

  group('where the web image gets its serving configuration', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dw_web_cache'));
    tearDown(() => root.deleteSync(recursive: true));

    File dockerfile(String contents) {
      final file = File(p.join(root.path, 'Dockerfile'));
      file.writeAsStringSync(contents);
      return file;
    }

    test('a copied file is read from the build context', () {
      final conf = File(p.join(root.path, 'app_flutter', 'nginx.conf'))
        ..parent.createSync(recursive: true);
      conf.writeAsStringSync(_shippedConfiguration);

      final gathered = dwWebServingConfiguration(
        projectRoot: root,
        dockerfile: dockerfile('''
FROM nginx:alpine
COPY --from=build /workspace/app_flutter/build/web /usr/share/nginx/html
COPY app_flutter/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
'''),
      );
      expect(gathered, contains('location /'));
      expect(
        dwEntryPointPolicies(gathered!)['/main.dart.js'],
        DwCacheReuse.revalidated,
      );
    });

    // The `COPY --from=build` line above names a path under /usr/share, and a
    // build stage rather than the context. Reading it as a serving
    // configuration would mean reading the compiled bundle.
    test('a stage copy is not mistaken for a configuration', () {
      expect(
        dwWebServingConfiguration(
          projectRoot: root,
          dockerfile: dockerfile(
            'FROM nginx:alpine\n'
            'COPY --from=build /workspace/web /etc/nginx/conf.d/default.conf\n',
          ),
        ),
        isNull,
      );
    });

    // The older shape, still in every project generated before the split.
    test('a heredoc written straight into the image is read too', () {
      final gathered = dwWebServingConfiguration(
        projectRoot: root,
        dockerfile: dockerfile('''
FROM nginx:alpine
COPY <<'EOF' /etc/nginx/conf.d/default.conf
$_immutableAssetsConfiguration
EOF
EXPOSE 80
'''),
      );
      expect(gathered, contains('expires 1y'));
      expect(
        dwEntryPointPolicies(gathered!)['/main.dart.js'],
        DwCacheReuse.freely,
      );
    });

    test('a Dockerfile that serves nothing of its own yields nothing', () {
      expect(
        dwWebServingConfiguration(
          projectRoot: root,
          dockerfile: dockerfile('FROM nginx:alpine\nEXPOSE 80\n'),
        ),
        isNull,
      );
    });

    test('a missing Dockerfile is not an empty one', () {
      expect(
        dwWebServingConfiguration(
          projectRoot: root,
          dockerfile: File(p.join(root.path, 'nowhere', 'Dockerfile')),
        ),
        isNull,
      );
    });
  });

  group('web-cache-policy', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dw_web_policy'));
    tearDown(() => root.deleteSync(recursive: true));

    final check = dwLocalDeployChecks.firstWhere(
      (c) => c.id == 'web-cache-policy',
    );

    DwDeployContext contextIn(Directory root) => DwDeployContext(
      projectRoot: root,
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
      target: DwDeployTarget(
        environment: 'staging',
        host: '203.0.113.10',
        sshUser: 'root',
        deployUser: 'deployer',
        os: 'ubuntu',
        repo: 'git@github.com:acme/shop.git',
        branch: 'master',
        sslEmail: 'ops@example.com',
        webAppDomain: 'app.example.com',
      ),
      serverpod: DwServerpodConfig(
        environment: 'staging',
        relativePath: 'shop_server/config/staging.yaml',
        apiServer: DwServerEndpoint(
          name: 'apiServer',
          port: 8080,
          publicHost: 'api.example.com',
          publicPort: 443,
          publicScheme: 'https',
        ),
        insightsServer: null,
        webServer: null,
        databaseHost: 'postgres',
        databasePort: 5432,
        databaseName: 'shop',
        databaseUser: 'shop',
        redisEnabled: false,
        redisHost: null,
      ),
    );

    void writeWebImage(String configuration) {
      File(p.join(root.path, 'shop_flutter', 'nginx.conf'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(configuration);
      File(p.join(root.path, 'shop_flutter', 'Dockerfile')).writeAsStringSync(
        'FROM nginx:alpine\n'
        'COPY shop_flutter/nginx.conf /etc/nginx/conf.d/default.conf\n',
      );
    }

    test('nothing to judge without a web Dockerfile', () async {
      expect((await check.evaluate(contextIn(root))).skipped, isTrue);
    });

    test('accepts the configuration the template ships', () async {
      writeWebImage(_shippedConfiguration);
      final verdict = await check.evaluate(contextIn(root));
      expect(verdict.passed, isTrue, reason: verdict.detail);
    });

    test('names the entry points an immutable rule would freeze', () async {
      writeWebImage(_immutableAssetsConfiguration);
      final verdict = await check.evaluate(contextIn(root));

      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('/main.dart.js'));
      // The half a fix has to be accompanied by, or the finding is only half
      // reported: the copies already out there.
      expect(verdict.fix, contains('hard-reload'));
    });

    test('an image serving no configuration of its own is a finding', () async {
      File(p.join(root.path, 'shop_flutter', 'Dockerfile'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('FROM nginx:alpine\nEXPOSE 80\n');

      final verdict = await check.evaluate(contextIn(root));
      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('no serving configuration'));
    });

    // Reading configuration text can miss things a running server would show —
    // an include outside the build context, a header a front proxy adds — so
    // this one warns and `web-cache-headers`, which observed the response,
    // errors.
    test('warns rather than blocking a deploy', () {
      expect(check.severity, DwCheckSeverity.warning);
      expect(
        dwRemoteDeployChecks
            .firstWhere((c) => c.id == 'web-cache-headers')
            .severity,
        DwCheckSeverity.error,
      );
    });

    // The header check asks the site, not the server, so it needs no SSH — and
    // must still run when the SSH checks have failed.
    test('the deployed site is asked over HTTP, not over SSH', () {
      expect(
        dwRemoteDeployChecks
            .firstWhere((c) => c.id == 'web-cache-headers')
            .requiresSsh,
        isFalse,
      );
    });
  });

  // Inside the monorepo the skeleton itself is the thing that must not rot: it
  // is what `dartway create` hands to a project that will never read this file.
  group('the configuration the template ships', () {
    final shipped = File(
      p.join(
        Directory.current.path,
        '..',
        '..',
        'template',
        'dartway_starter_flutter',
        'nginx.conf',
      ),
    );

    test('revalidates every entry point a build overwrites', () {
      final policies = dwEntryPointPolicies(shipped.readAsStringSync());
      final notRevalidated = policies.entries
          .where((entry) => entry.value != DwCacheReuse.revalidated)
          .map((entry) => '${entry.key} -> ${entry.value.name}')
          .toList();
      expect(notRevalidated, isEmpty);
    }, skip: shipped.existsSync() ? null : 'not running inside the monorepo');
  });
}
