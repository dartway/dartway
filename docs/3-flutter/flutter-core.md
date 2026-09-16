# How is the app core built and started?

Every DartWay app has one ambient object, `dw`, and every screen reaches the server, the
notifications and the error pipeline through it. This page is about that object: what it is made of,
what it needs to exist, and the two moments of its life — being built and being started.

## Two classes, one ambient `dw`

| Class | What it is |
|---|---|
| `DwFlutterToolbox` | The toolbox with no server: `DwFlutterConfig`, plugins (`dw.plugins`), notifications (`dw.notify`), actions (`dw.action`), confirmations, the error pipeline (`dw.handleError`, `dw.errorContext`). |
| `DwFlutterCore` | `DwFlutterToolbox` plus the data layer: one `DwAppClient` (`dw.client`) and the Riverpod bindings over it — `dw.request`, `dw.pages`, `dw.table`, `dw.window`, `dw.command`, `dw.files`, `dw.uploader()`, `dw.accountId`, `dw.liveStatus`, `dw.incompatibility`, `dw.signIn`, `dw.signOut`. |

An app that talks to a DartWay server builds a `DwFlutterCore`. `DwFlutterToolbox` exists on its own for
the parts that have no server — a plugin receives a `DwFlutterToolbox` in `init`, because that is the class
that declares `plugins:` (see [plugins](plugins.md)).

`dw` is **the app's own variable**, declared in `lib/core/dw_core.dart`:

```dart
late DwFlutterCore dw;
```

`late`, and not `final`: the app assigns it once, and a widget test assigns it once per test.

## What the core needs

From `example/dartway_example_flutter/lib/core/dw_core.dart`, where a function builds it for the app
and for each widget test:

```dart
dw = DwFlutterCore(
  config: DwFlutterConfig(
    appVersion: appVersion,
    refusalText: (refusal) => refusalText(appL10n, refusal),
    updateRequiredScreen: (context, refusal) =>
        UpdateRequiredPage(refusal: refusal),
    onErrorReport: _onErrorReport,
  ),
  protocol: dartwayExampleProtocol,
  baseUrl: baseUrl,
  httpTransport: httpTransport,     // null in the app, the fake server's in a test
  liveConnector: liveConnector,     // likewise
  tokenStore: tokenStore,           // likewise: a DwMemoryTokenStore in a test
  clientOptions: clientOptions,
  plugins: [if (tokenStore == null) DwSharedPreferences()],
);
```

- **`protocol`** — the generated `DwWireProtocol` of the project's shared package: every DTO the
  client and the server agree on.
- **`baseUrl`** — where the server is: `https://api.example.com`, or a prefix it is proxied under.
  An `http` or `https` URL without a query or fragment; anything else throws `ArgumentError`.
- **`httpTransport`, `liveConnector`, `storageTransport`, `clientOptions`** — left out by the app;
  a test passes the fake server's transports and short timings (`dwFakeClientOptions` from
  `package:dartway_client/testing.dart`).
- **`tokenStore`** — where the session is kept; see below.

### `DwFlutterConfig`

| Field | Required by `DwFlutterCore` | What it is for |
|---|---|---|
| `appVersion` | yes | The build, `<semver>+<build>` (`1.4.2+57`). Sent on every call as `Dw-App-Version`; the server refuses a build below its minimum. Shown in error reports. |
| `refusalText` | yes | Turns a `DwCallRefusal` — a code with parameters, never a sentence — into words. `dw.action` shows it. See [actions and refusal texts](actions-and-refusal-texts.md). |
| `updateRequiredScreen` | no | The page put over the whole app once this build can no longer talk to its server. See [update required](update-required.md). |
| `onErrorReport` | no | Receives every `DwErrorReport`. Without it a report is only `debugPrint`ed. See [error reporting](error-reporting.md). |
| `confirmDialogBuilder` | no | Replaces the built-in `DwConfirmDialog` for `dw.action(confirmation: ...)`. |
| `defaultModelGetter` | no | Placeholder values for skeletons in `dwBuildAsync` / `dwBuildListAsync` when the caller passes none. See [the data layer](data-layer.md#rendering-an-asyncvalue). |

**Why two fields are required.** A server answers "no" with a code, and an app that cannot render
the code shows the user nothing at all. A server that stops supporting old builds needs to know
which build is calling. Both failures are silent at runtime, so the constructor refuses a config
without them — with an `ArgumentError` naming the field, before the core exists. A malformed
`appVersion` (not `<semver>+<build>`) throws `FormatException` at the same moment.

## Two phases: build, then start

**The constructor builds and connects nothing.** It checks the config, creates the client and claims
the live slot (below). No plugin runs, no storage is read, nothing goes to the network.

**`init()` starts the core**, in this order:

1. every plugin's `init(core)`, awaited, in declaration order;
2. `client.start()` — reads the stored session. It does **not** wait for the server: a start with no
   network is a start, and watched requests keep retrying until the server answers.

A signed-in user therefore opens straight into the app: `dw.accountId` is known from the stored
session before the server has seen the token. If the server rejects the token later, the session
ends and `dw.accountId` becomes `null`.

## `DwAppRunner` and `DwAppBootstrapper`

`init()` is run by the bootstrap, not by hand. From `example/dartway_example_flutter/lib/dartway_example_app.dart`:

```dart
void run() {
  // the core is built just before this, by the function above
  DwAppRunner(
    appInitializers: [dw.init],
    supportedLocales: AppLocalizations.supportedLocales,
    child: const ExampleApp(),
  ).run();
}
```

`main.dart` only chooses the concrete values — the server address from
`--dart-define=DW_BACKEND_URL=...`, or `localhost` / `10.0.2.2` on a local run — and calls `run()`.

`DwAppRunner.run()`:

- initializes the Flutter binding and keeps the native splash up
  (`DwAppLoadingOptions.withNativeSplash()` by default; `withoutNativeSplash(loadingScreen:)` shows
  a widget instead);
- routes uncaught errors — `FlutterError.onError` and the platform dispatcher's `onError` — into
  `dw.handleError` with `DwErrorSource.zone`, unless `onError:` is given;
- initializes date formatting for `supportedLocales`;
- mounts `ProviderScope` → `DwAppBootstrapper` → your app.

`DwAppBootstrapper` runs the initializers in order and shows, in this priority:

1. `DwFlutterConfig.updateRequiredScreen`, when the client reports the build incompatible — over the loading
   and error screens too;
2. the error screen, when an initializer threw — built from the error itself
   (`DwAppLoadingOptions.defaultErrorScreen` prints it, because the person looking at a failed start
   is usually the one asked what happened);
3. the loading screen while initializers run;
4. the app.

`DwAppBootstrapper` is public so a widget test can mount the app exactly as the runner does, without
the runner's process-wide effects. The harness in `test/support/` of both `example/` and the
skeleton does this when a test asks for `bootstrap: true`.

## Where the session is kept

The client stores the whole `DwAuthSession` (account id and token), not only the token: the account
id is what state is keyed by, and what the app renders before the server has answered.

By default `DwFlutterCore` keeps it through **the `DwKeyValueStorePlugin` role** — whichever declared
plugin claims it. `DwSharedPreferences` from `dartway_shared_preferences` does:

```dart
plugins: [DwSharedPreferences()],
```

**Declare none and pass no `tokenStore`, and `init()` throws** a `StateError` naming both fixes. A
sign-in that cannot survive a restart is a bug users report as "it keeps logging me out", so the
framework refuses to start without an answer.

The other answer is an explicit `tokenStore:` — any `DwTokenStore` (`read`, `write`, `clear`). A test
passes `DwMemoryTokenStore(session)`, which also decides whether the test starts signed in; with a
store of its own the core needs no storage plugin at all, which is why the example declares
`DwSharedPreferences()` only when `tokenStore` is `null`.

## One core at a time, and nothing static

The framework keeps exactly one process-wide pointer: the live core, for code that has no other way
to reach it (the zone error handler, `dwBuildAsync`'s error branch). It is bound to the core's
lifetime, not to the process:

- constructing a core claims it; constructing a second while the first is alive throws `StateError`
  ("One core at a time");
- `dispose()` stops the client — closes every watch and the live socket, ends unanswered calls — and
  releases it. A disposed core is not reused; build a new one.

So a widget test builds a core against its own fake server, pumps the app, and disposes it in
`tearDown`; the next test builds another. `packages/dartway_core_flutter/test/dw_flutter_core_test.dart`
builds, disposes and rebuilds a core three times in one process. Forgetting `dispose` shows up in the
next test as "Another dw core is alive", not as data leaking between tests.

A feature reads `dw` while it builds, not only on a tap — so a widget test that pumps a feature
without building a core fails with "Dw is not initialized".

## Related

- [The data layer](data-layer.md) — what the core's bindings return.
- [Plugins](plugins.md) — what `plugins:` accepts.
- [Update required](update-required.md), [error reporting](error-reporting.md).
- [Project layout](../1-getting-started/project-layout.md) — where `dw_core.dart` sits.
