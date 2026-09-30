---
title: "The environment is read once into AppEnvironment, and another service's API is ctx.http"
affects:
  dartway_core_server: "0.21.0-dev.10"
  dartway_cli: "0.16.0"
---

## Who is affected

Every project: `dart run dartway_cli:dartway check` now fails on `Platform.environment` in the server package's `lib/`
outside `lib/src/core/environment.dart` (`forbiddenEnvironmentRead`), and on `HttpClient(` or an
import of `package:http/…` anywhere in its `lib/` (`forbiddenHttpClient`) — and, in its `bin/`, on
`Platform.environment` outside `DwLocalEnvironment.overlay(…)` and on any map read by a variable's
name (`env['PORT']`). So every project whose `bin/server.dart` parses `PORT`, `DW_ALLOWED_ORIGINS` or
`DW_STORAGE_PROVISION` by hand moves, as does one that calls `AppFiles.storageConfig` (the
skeleton's, now gone). `DwFirstAdministrator` no longer reads the environment (`variable:` and
`environment:` are gone; it takes `identifier:`), and `DwAppServer.start` no longer reads
`DW_MIGRATE_ONLY` (it takes `migrateOnly:`). A class that implements `DwCallContext` itself adds
`http`.

## What to change

**1. One environment file.** Create `lib/src/core/environment.dart` with the framework's variables
and one typed sub-config per concern of your own; move every read of a variable there:

    final class AppEnvironment {
      const AppEnvironment({required this.server, required this.sms});

      static AppEnvironment read(Map<String, String> variables) =>
          DwEnvironmentReader.read(variables, (read) => AppEnvironment(
            server: DwServerEnvironment.read(
              read,
              defaultPublicBucket: AppFiles.defaultPublicBucket,
              defaultPrivateBucket: AppFiles.defaultPrivateBucket,
            ),
            sms: AppSmsEnvironment(
              login: read.required('SMS_LOGIN'),
              password: read.required('SMS_PASSWORD'),
            ),
          ));

      final DwServerEnvironment server;
      final AppSmsEnvironment sms;
    }

`read.required` / `optional` / `integer(…, fallback:)` / `flag` / `list`, and `read.report('…')` for a
rule across variables (both or neither). A value that was read on first use with a `?? throw` is
`read.required` now: the start fails with every missing variable at once. Keep the bucket defaults
as constants on `AppFiles` (`defaultPublicBucket`, `defaultPrivateBucket`) and delete
`AppFiles.storageConfig`.

**2. `bin/server.dart` parses nothing:**

    - final env = DwLocalEnvironment.overlay(Platform.environment);
    - final storage = AppFiles.storageConfig(env);
    - if (storage != null && env['DW_STORAGE_PROVISION'] == 'true') { … }
    - port: int.parse(env['PORT'] ?? '8080'),
    - allowedOrigins: { for (final entry in (env['DW_ALLOWED_ORIGINS'] ?? '').split(',')) … },
    + final env = AppEnvironment.read(DwLocalEnvironment.overlay(Platform.environment));
    + final storage = env.server.storage;
    + if (storage != null && env.server.provisionStorage) {
    +   await DwFileStorageSetup.provision(storage);
    + }
    + database: env.server.database,
    + port: env.server.port,
    + settings: DwServerSettings(allowedOrigins: env.server.allowedOrigins),

and hand each sub-config to the server factory, which passes it to what uses it. The first
administrator and migrate-only come from the same read. Both are required parameters now —
`start({required bool migrateOnly})`, `DwFirstAdministrator({required String? identifier})` — so the
compiler names every place that has to pass them (`migrateOnly: false` in `bin/seed_dev.dart`,
`identifier: null` where no administrator is meant); skipping them would have made a deploy's
migration step start serving and the administrator silently disappear:

    + adminIdentifier: env.server.adminIdentifier,   // → DwFirstAdministrator(identifier: …)
    - await server.start();
    + await server.start(migrateOnly: env.server.migrateOnly);

In the factory: `DwFirstAdministrator(grant: …, identifier: adminIdentifier)`, with
`required String? adminIdentifier` as its parameter so the entry points and test harnesses say what
they mean.

A project that named its administrator with a variable of its own (Molodey's
`MOLODEY_BOOTSTRAP_ADMIN`, U90's `AppBootstrap.adminVariable`) either renames it to
`DW_ADMIN_IDENTIFIER` in `deploy/config.yaml` and the secret store (`dartway secret set
DW_ADMIN_IDENTIFIER --env <name>`), or keeps its name, reads it in `AppEnvironment` —
`read.optional('MOLODEY_BOOTSTRAP_ADMIN')` — and passes that as `identifier:`. `bin/seed_dev.dart`
reads `AppEnvironment` the same way; any other `env['NAME']` in `bin/` becomes a field of
`AppEnvironment`.

Studio: `StudioEnvironment`, `WorkerConfiguration.fromEnvironment` and
`AutomationConfiguration.fromEnvironment` fold into sub-configs of `AppEnvironment`, and so do the
reads of `STUDIO_CLAUDE_EXECUTABLE`, `STUDIO_WORKSPACES`, `STUDIO_DARTWAY_CLI` and `PATH` — a child
process's `PATH` is a field (`read.optional('PATH')`) passed to what spawns it. A token only a
command-line entry point needs — `bin/import_github.dart`'s `STUDIO_TOKEN` — is read there, not in
`AppEnvironment`:

    final token = DwEnvironmentReader.read(
      DwLocalEnvironment.overlay(Platform.environment),
      (read) => read.required('STUDIO_TOKEN'),
    );

**3. Outbound HTTP through `ctx.http`.** Replace each client of your own:

    - final client = HttpClient()..connectionTimeout = timeout;
    - final request = await client.postUrl(url);
    - request.headers.contentType = ContentType.json;
    - request.write(jsonEncode(body));
    - final response = await request.close();
    - final text = await utf8.decodeStream(response);
    + final response = await ctx.http.post(url, json: body, timeout: timeout);
    + final text = response.body;

`package:http`'s `client.post(url, body: …)` becomes `ctx.http.post(url, body: …)` the same way. A
non-2xx status is still an answer (`response.statusCode`, `isSuccess`); what used to be a
`SocketException`, `TimeoutException` or `ClientException` is `DwOutboundException`
(`timedOut`). A redirect that must not carry a token is `followRedirects: false`. A service class
takes `ctx.http` (a `DwOutboundHttp`) per call instead of holding a client.

A client used only by a command-line entry point that has no server context — Studio's
`studio_remote_caller.dart`, used by `bin/import_github.dart` alone — is not the server's: move it to
`bin/` (or a tool package of its own). The check judges `lib/`, not `bin/`.

**4. Tests drop their transport seams.** A transport interface threaded through the server factory
for tests (Molodey's SMSC and amoCRM transports) is deleted together with its parameter; the test
scripts the test server's fake instead:

    server.http.when(
      (request) => request.url.host == 'smsc.ru',
      (request) => DwOutboundResponse(200, json: {'id': 1, 'cnt': 1}),
    );
    …
    expect(server.http.requests.single.form['phones'], '79990000001');

A request no rule answers fails the call with a `StateError`, so every test that reaches a provider
now says what the provider answers.

**5. Unit tests of a client class** (no server) hand it the fake's client instead of a transport of
their own:

    final http = DwFakeOutboundHttp()
      ..when((request) => true, (request) => DwOutboundResponse(200, body: 'OK'));
    await SmscGateway(settings).send(http.client(), phone, text);
    expect(http.requests.single.form['phones'], phone);

A `DwCallContext` of your own (a test double) adds `DwOutboundHttp get http` — `fake.client()`.

## How to check

`dart run dartway_cli:dartway check` reports no `forbiddenEnvironmentRead` or `forbiddenHttpClient`;
`dart run bin/server.dart` with a variable removed stops with `DwEnvironmentException` naming it;
`dart run dartway_cli:dartway test` is green.
