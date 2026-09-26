@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/vendor_framework.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The deployment of the example, on this machine: the stack rendered by the
/// same renderer, brought up by the same deploy steps — run by a local shell
/// instead of over SSH — and verified by the same outside probes, over plain
/// HTTP on one loopback port with the public host names carried in `Host`.
///
/// What it cannot prove is the part only a server has: DNS, the certificate,
/// the firewall and SSH itself. Everything between "the checkout is on the
/// machine" and "a browser gets the right answers" it runs for real.
void main() {
  final monorepo = () {
    var dir = Directory.current.absolute;
    while (!File(p.join(dir.path, 'example', '.dockerignore')).existsSync()) {
      if (dir.parent.path == dir.path) {
        throw StateError('not inside the monorepo');
      }
      dir = dir.parent;
    }
    return dir;
  }();

  final random = Random.secure();
  final suffix = List.generate(
    6,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  late Directory root;
  late Directory project;
  late String appDir;
  late int port;
  late DwStack stack;
  late DwDeployRunner runner;
  late DwOutsideProbe probe;
  late LocalShell shell;
  final log = StringBuffer();

  Future<DwSshResult> compose(String arguments) =>
      shell.run(DwComposeFiles.commandIn(appDir, arguments));

  /// A request to the stack, addressed to [url]'s host and delivered to the
  /// loopback port — exactly what a browser behind DNS would send.
  Future<({int status, HttpHeaders headers, String body})> send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(InternetAddress.loopbackIPv4, port);
    try {
      final request = await client.openUrl(method, Uri.parse(url));
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close();
      return (
        status: response.statusCode,
        headers: response.headers,
        body: await utf8.decodeStream(response),
      );
    } finally {
      client.close(force: true);
    }
  }

  /// A call to the server by its wire name, as a client sends it.
  Future<({int status, Map<String, Object?> json})> call(
    String origin,
    String wireName,
    Map<String, Object?> dto, {
    String? token,
    bool command = false,
    String? browserOrigin,
  }) async {
    final answer = await send(
      'POST',
      '$origin/dw/$wireName',
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'dw-protocol': '1',
        'authorization': ?(token == null ? null : 'Bearer $token'),
        'dw-idempotency-key': ?(command
            ? 'proof-${DateTime.now().microsecondsSinceEpoch}'
            : null),
        'origin': ?browserOrigin,
      },
      body: utf8.encode(jsonEncode(dto)),
    );
    expect(
      answer.headers.contentType?.mimeType,
      'application/json',
      reason:
          'POST $origin/dw/$wireName answered ${answer.status}: ${answer.body}',
    );
    return (
      status: answer.status,
      json: jsonDecode(answer.body) as Map<String, Object?>,
    );
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('dw_stack_proof_');
    project = Directory(p.join(root.path, 'project'));
    copyProject(Directory(p.join(monorepo.path, 'example')), project);
    // The example has no site; the proof gives it one, committed-shaped.
    File(p.join(project.path, 'app_site', 'build', 'index.html'))
      ..createSync(recursive: true)
      ..writeAsStringSync('<!DOCTYPE html><html><body>The club</body></html>');
    // The example builds against the local framework packages inside the
    // monorepo (the same reason every example and template here does), and
    // its dependency_overrides point outside any build context.
    vendorFramework(project: project, monorepo: monorepo);
    // Vendoring moves the overrides, so the locks name paths that are gone;
    // the images build `--enforce-lockfile`, and a project resolves before it
    // deploys (#278).
    for (final (package, tool) in [
      ('dartway_example_shared', 'dart'),
      ('dartway_example_server', 'dart'),
      ('dartway_example_flutter', 'flutter'),
    ]) {
      final resolved = await Process.run(tool, [
        'pub',
        'get',
      ], workingDirectory: p.join(project.path, package));
      if (resolved.exitCode != 0) {
        throw StateError('$tool pub get in $package: ${resolved.stderr}');
      }
    }

    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = socket.port;
    await socket.close();

    stack = DwStack(
      target: DwDeployTarget.parse(
        configYaml(
              extra:
                  '  site:\n    domain: site.dwproof.test\n    source: app_site/build\n'
                  '  storage: bundled\n  storage_domain: files.dwproof.test\n',
            )
            .replaceAll('api.example.com', 'api.dwproof.test')
            .replaceAll('app.example.com', 'app.dwproof.test'),
        environment: 'staging',
      ),
      serverPackage: 'dartway_example_server',
      flutterPackage: 'dartway_example_flutter',
      front: DwPlainHttpFront(port),
    );

    // The local checks a deployment runs first, on the vendored copy.
    final context = DwDeployContext(projectRoot: project, stack: stack);
    for (final check in dwLocalDeployChecks.where((c) => c.partOfDeploy)) {
      if (check.id == 'site-source') continue; // the copy is not a repository
      final verdict = await check.evaluate(context);
      if (!verdict.passed && !verdict.skipped) {
        throw StateError('${check.id}: ${verdict.detail}');
      }
    }

    // The checkout directory names the Compose project; unique per run.
    appDir = p.join(root.path, 'dwproof$suffix');
    final renderer = DwStackRenderer(stack: stack, buildContext: project.path);
    for (final dir in ['http', 'api', 'app']) {
      Directory(p.join(appDir, 'nginx.d', dir)).createSync(recursive: true);
    }
    File(
      p.join(appDir, DwComposeFiles.rendered),
    ).writeAsStringSync(renderer.composeFile);
    File(p.join(appDir, 'nginx.conf')).writeAsStringSync(renderer.nginxFile);

    shell = LocalShell();
    probe = DwOutsideProbe(
      connectTo: (host: InternetAddress.loopbackIPv4.address, port: port),
    );
    runner = DwDeployRunner(
      ssh: shell,
      stack: stack,
      appDir: appDir,
      storeDir: p.join(root.path, 'store'),
      probe: probe,
      buildContext: project.path,
    );

    final store = runner.store;
    final created = await store.ensureDirectory();
    final generated = await store.generateMissing(stack.generatedSecrets);
    if (!created.ok || !generated.ok) {
      throw StateError('secret store: ${created.stderr}${generated.stderr}');
    }

    final failed = await executeDeploySteps(runner.steps(skipGitUpdate: true));
    if (failed != null) {
      log.writeln((await compose('logs --no-color --tail 100')).stdout);
      throw StateError('deploy step "$failed" failed; logs:\n$log');
    }
  });

  tearDownAll(() async {
    if (!root.existsSync()) return;
    final down = await compose('down --volumes --remove-orphans --rmi local');
    if (!down.ok) {
      stderr.writeln('teardown: ${down.stderr}');
    }
    root.deleteSync(recursive: true);
  });

  test('every outside probe answers as a browser and an app need', () async {
    final results = await runner.verifyFromOutside(attempts: 3);
    expect(reportOutsideVerification(results), 0, reason: results.join('\n'));
    expect(results.map((r) => r.title), hasLength(9));
  });

  test(
    'the api host answers a real DTO call: sign in, then read the profile',
    () async {
      const phone = '79990007777';
      final ticket = await call(stack.apiOrigin, 'DwRequestCode', {
        'kind': 'phone',
        'identifier': phone,
      }, command: true);
      expect(ticket.status, 200, reason: '${ticket.json}');
      expect(ticket.json['status'], 'ok');
      final ticketId = (ticket.json['result']! as Map)['id'] as String;

      // The example delivers codes to the server log.
      final logs = await compose('logs --no-color --no-log-prefix server');
      final code = RegExp(
        'Sign-in code for $phone: (\\d+)',
      ).allMatches(logs.stdout).last.group(1)!;

      final session = await call(stack.apiOrigin, 'DwVerifyCode', {
        'ticketId': ticketId,
        'code': code,
        'registration': {'firstName': 'Proof'},
      }, command: true);
      expect(session.json['status'], 'ok', reason: '${session.json}');
      final token = (session.json['result']! as Map)['token'] as String;

      final profile = await call(
        stack.apiOrigin,
        'GetMyProfile',
        {},
        token: token,
      );
      expect(profile.status, 200, reason: '${profile.json}');
      final result = profile.json['result']! as Map;
      expect(result['phone'], phone);
      expect(result['firstName'], 'Proof');

      // The same call through the app host — the web app's own origin.
      final viaApp = await call(
        stack.appOrigin,
        'GetMyProfile',
        {},
        token: token,
        browserOrigin: stack.appOrigin,
      );
      expect(viaApp.status, 200);
      expect((viaApp.json['result']! as Map)['phone'], phone);

      // And an anonymous one is the server's own refusal, not the proxy's.
      final anonymous = await call(stack.appOrigin, 'GetMyProfile', {});
      expect(anonymous.status, 401);
      expect(anonymous.json['status'], 'unauthenticated');
    },
  );

  test(
    'the app host serves the Flutter build itself, not a default page',
    () async {
      final index = await send('GET', '${stack.appOrigin}/');
      expect(index.status, 200);
      expect(index.body, contains('flutter_bootstrap.js'));
      final bootstrap = await send(
        'GET',
        '${stack.appOrigin}/flutter_bootstrap.js',
      );
      expect(bootstrap.status, 200);
      expect(bootstrap.headers.value('cache-control'), 'no-cache');
      // A Flutter route is not a file: the app answers it.
      final route = await send('GET', '${stack.appOrigin}/admin/users');
      expect(route.status, 200);
      expect(route.body, contains('flutter_bootstrap.js'));
    },
  );

  test('a call body past the server limit is refused by the server, not the '
      'proxy', () async {
    final answer = await send(
      'POST',
      '${stack.appOrigin}/dw/GetMyProfile',
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'dw-protocol': '1',
      },
      body: utf8.encode('{"pad":"${'x' * (2 << 20)}"}'),
    );
    expect(
      answer.headers.contentType?.mimeType,
      'application/json',
      reason:
          '${answer.status}: ${answer.body.substring(0, min(200, answer.body.length))}',
    );
    expect(
      answer.status,
      isNot(413),
      reason: 'nginx refused it before the server',
    );
  });

  test('the site host serves the site directory', () async {
    final answer = await send('GET', '${stack.siteOrigin}/');
    expect(answer.status, 200);
    expect(answer.body, contains('The club'));
  });

  group('storage', () {
    Future<({String url, Map<String, String> headers})> presignPut(
      String key,
      List<int> body, {
      required String bucket,
    }) async {
      final store = await shell.run("cat '${runner.store.file}'");
      final secrets = DwSecretStore.parse(store.stdout);
      return _presignPut(
        endpoint: stack.storageOrigin!,
        bucket: bucket,
        key: key,
        accessKey: secrets[DwStack.storageAccessKey]!,
        secretKey: secrets[DwStack.storageSecretKey]!,
        contentType: 'image/png',
        length: body.length,
      );
    }

    test('a browser on the app origin uploads through a presigned PUT', () async {
      final body = List<int>.generate(4096, (i) => i % 256);
      final key = 'chatAttachment/proof-$suffix.png';
      final signed = await presignPut(
        key,
        body,
        bucket: stack.privateBucketName,
      );

      final preflight = await send(
        'OPTIONS',
        signed.url,
        headers: {
          'origin': stack.appOrigin,
          'access-control-request-method': 'PUT',
          'access-control-request-headers': 'content-type,if-none-match',
        },
      );
      expect(preflight.status, inInclusiveRange(200, 204));
      expect(
        preflight.headers.value('access-control-allow-origin'),
        stack.appOrigin,
      );

      final put = await send(
        'PUT',
        signed.url,
        headers: {...signed.headers, 'origin': stack.appOrigin},
        body: body,
      );
      expect(put.status, 200, reason: put.body);
      expect(put.headers.value('access-control-allow-origin'), stack.appOrigin);

      // Conditional write survives the proxy: the same ticket cannot overwrite.
      final again = await send(
        'PUT',
        signed.url,
        headers: {...signed.headers, 'origin': stack.appOrigin},
        body: body,
      );
      expect(again.status, 412, reason: again.body);
    });

    test('an object in the private bucket is not readable without a '
        'signature; one in the public bucket is, at the base URL the server '
        'is given, and neither bucket lists its keys', () async {
      final body = List<int>.generate(64, (i) => i);
      final privateKey = 'chatAttachment/secret-$suffix.png';
      final publicKey = 'avatar/open-$suffix.png';
      for (final (bucket, key) in [
        (stack.privateBucketName, privateKey),
        (stack.publicBucketName, publicKey),
      ]) {
        final signed = await presignPut(key, body, bucket: bucket);
        final put = await send(
          'PUT',
          signed.url,
          headers: signed.headers,
          body: body,
        );
        expect(put.status, 200, reason: '$bucket: ${put.body}');
      }

      final private = await send(
        'GET',
        '${stack.storageOrigin}/${stack.privateBucketName}/$privateKey',
      );
      expect(private.status, 403, reason: private.body);
      expect(private.body, contains('AccessDenied'));

      // What the running server was given, not what the renderer meant to.
      final printed = await compose(
        'exec -T server printenv ${DwStack.storagePublicBaseUrlKey}',
      );
      expect(printed.ok, isTrue, reason: printed.stderr);
      final base = printed.stdout.trim();
      expect(base, '${stack.storageOrigin}/${stack.publicBucketName}');
      final public = await send('GET', '$base/$publicKey');
      expect(public.status, 200, reason: public.body);
      expect(public.body.length, body.length);

      for (final bucket in [stack.publicBucketName, stack.privateBucketName]) {
        final listing = await send(
          'GET',
          '${stack.storageOrigin}/$bucket?list-type=2',
        );
        expect(listing.status, 403, reason: '$bucket: ${listing.body}');
      }
    });

    test('another origin is not admitted', () async {
      final preflight = await send(
        'OPTIONS',
        '${stack.storageOrigin}/${stack.privateBucketName}/x',
        headers: {
          'origin': 'http://evil.dwproof.test:$port',
          'access-control-request-method': 'PUT',
        },
      );
      expect(preflight.headers.value('access-control-allow-origin'), isNull);
    });

    test('the server reaches storage by the URL browsers sign', () async {
      final result = await compose(
        'exec -T server wget -q -O /dev/null '
        '${stack.storageOrigin}/health',
      );
      expect(result.ok, isTrue, reason: result.stderr);
    });
  });

  test('a new server that cannot migrate fails the deploy loudly in its own '
      'words, and the next deploy recovers', () async {
    final storeFile = File(runner.store.file);
    final original = storeFile.readAsStringSync();
    try {
      await runner.store.setSecret(
        key: DwStack.databasePasswordKey,
        value: 'not-the-password',
      );
      expect((await runner.renderEnvironment()).ok, isTrue);

      final replaced = await runner.replaceServer();
      expect(replaced.ok, isFalse);
      expect(replaced.stderr, contains('could not apply its migrations'));
      // The server's own words about why, not a paraphrase.
      expect(
        '${replaced.stdout}${replaced.stderr}',
        contains('password authentication failed'),
      );
      expect(replaced.stderr, contains('previous server is running again'));
      // One-off migration runs leave nothing behind.
      final leftovers = await compose('ps -aq --status exited');
      expect(leftovers.ok, isTrue);
    } finally {
      storeFile.writeAsStringSync(original);
      expect((await runner.renderEnvironment()).ok, isTrue);
    }
    final recovered = await runner.replaceServer();
    expect(recovered.ok, isTrue, reason: recovered.stderr);
    expect((await probe.health(stack.apiOrigin)).passed, isTrue);
  });

  test('the server stops gracefully on SIGTERM', () async {
    final stopped = await compose('stop server');
    expect(stopped.ok, isTrue, reason: stopped.stderr);
    final logs = await compose('logs --no-color --no-log-prefix server');
    expect(logs.stdout, contains('stopping'));
    expect(logs.stdout, contains('DartWay server stopped'));
    final id = (await compose('ps -aq server')).stdout.trim();
    final state = await shell.run(
      "docker inspect -f '{{.State.ExitCode}}' '$id'",
    );
    // 0, not 137: the process ended itself inside the grace period rather
    // than being killed when it ran out.
    expect(state.stdout.trim(), '0');
  });
}

/// A presigned S3 PUT bound to its length, content type and `if-none-match`,
/// signed as SigV4 defines it — the shape the framework's uploads use.
({String url, Map<String, String> headers}) _presignPut({
  required String endpoint,
  required String bucket,
  required String key,
  required String accessKey,
  required String secretKey,
  required String contentType,
  required int length,
}) {
  final uri = Uri.parse(endpoint);
  final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  final now = DateTime.now().toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${now.year}${two(now.month)}${two(now.day)}';
  final stamp = '${date}T${two(now.hour)}${two(now.minute)}${two(now.second)}Z';
  const region = 'us-east-1';
  final scope = '$date/$region/s3/aws4_request';
  final path = '/$bucket/$key';
  final signedHeaders = {
    'content-length': '$length',
    'content-type': contentType,
    'host': host,
    'if-none-match': '*',
  };
  final names = signedHeaders.keys.toList()..sort();
  String enc(String s) => Uri.encodeQueryComponent(s).replaceAll('+', '%20');
  final query = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': '$accessKey/$scope',
    'X-Amz-Date': stamp,
    'X-Amz-Expires': '600',
    'X-Amz-SignedHeaders': names.join(';'),
  };
  final canonicalQuery = (query.keys.toList()..sort())
      .map((k) => '${enc(k)}=${enc(query[k]!)}')
      .join('&');
  final canonical = [
    'PUT',
    path,
    canonicalQuery,
    names.map((n) => '$n:${signedHeaders[n]}\n').join(),
    names.join(';'),
    'UNSIGNED-PAYLOAD',
  ].join('\n');
  final toSign = [
    'AWS4-HMAC-SHA256',
    stamp,
    scope,
    sha256.convert(utf8.encode(canonical)).toString(),
  ].join('\n');
  List<int> hmac(List<int> k, String data) =>
      Hmac(sha256, k).convert(utf8.encode(data)).bytes;
  final signingKey = hmac(
    hmac(hmac(hmac(utf8.encode('AWS4$secretKey'), date), region), 's3'),
    'aws4_request',
  );
  final signature = Hmac(sha256, signingKey).convert(utf8.encode(toSign));
  return (
    url: '$endpoint$path?$canonicalQuery&X-Amz-Signature=$signature',
    headers: {'content-type': contentType, 'if-none-match': '*'},
  );
}

/// Copies a project without what a checkout would not carry either.
