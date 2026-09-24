# What does an old build show when the server no longer supports it?

Apps on phones do not update when the server does. Sooner or later the server changes in a way an old
build cannot follow, and that build keeps running on someone's phone — sending calls the server
refuses, one screen at a time, each failure looking like a different bug.

DartWay makes it one state with one screen: the server says "this build is too old" once, the client
remembers it, and the app shows a full-screen "update the app" page over everything.

## Two causes, one family

| Code | Cause | Who fixes it |
|---|---|---|
| `dw.updateRequired` (`DwCoreRefusal.updateRequired`) | The app was compiled with an older breaking line of the project's contract than the server's. | The user: the store has a newer build. |
| `dw.protocolUnsupported` (`DwCoreRefusal.protocolUnsupported`) | The client speaks a framework protocol version the server does not. | The operator: a framework version skew between app and server. |

Both are `DwCoreRefusal.incompatibilities` — `refusal.isIncompatibility` is `true` for either. They are
two codes rather than one because the cause differs, and so do the words on the page.

## How the server decides

Every call carries two headers the client sets itself:

- `Dw-Protocol` — the framework's protocol version (`dwProtocolVersion`);
- `Dw-Contract-Version` — the version of the project's contract the app was compiled with: the
  shared package's `version:`, which `dart run dartway_cli:dartway generate` writes into the protocol both sides use.

The server answers `426` with status `incompatible` when the protocol differs, or when the app's
contract belongs to an older **breaking line** than the server's — the major version, or the minor one
below 1.0 (`DwContractVersion`); a call with no contract version counts as the oldest. The live
socket's upgrade carries the same versions and is closed with `DwCloseCode.incompatible` for the same
reason. An app on a *newer* line than the server is not refused: the server is behind, and a call it
does not know is answered as unknown.

**The minimum lives in the code.** Whoever removes or renames anything an installed app sends or
reads raises the breaking line of the shared package's version in the same pull request; nothing is
set in an environment at deploy time. See [wire and versions](../2-core/wire-and-versions.md).

`Dw-App-Version` (`DwFlutterConfig.appVersion`, `<semver>+<build>`) still travels: it labels the
session key the app signs in with. It decides nothing.

## What the client does

The first incompatible answer makes the client **incompatible for good**:

- `dw.incompatibility` — a `DwCallRefusal?` provider — becomes the refusal;
- `dw.liveStatus` becomes `DwConnectionStatus.incompatible`, and the live socket is closed and not
  reopened;
- every later call answers `DwCallRefused` with that refusal **without reaching the network**, and
  every watched request shows it as a `DwRefusalException`.

Nothing under the app can reach the server any more, and nothing is retried: only another build can.

## `DwFlutterConfig.updateRequiredScreen`

The project supplies the page:

```dart
DwFlutterConfig(
  // ...
  updateRequiredScreen: (context, refusal) => UpdateRequiredPage(refusal: refusal),
)
```

`DwAppBootstrapper` — mounted by `DwAppRunner` — watches the client and, once it is incompatible,
builds this page **in place of the app**, over the loading and error screens too. It is built above
the app's `MaterialApp`, so the page brings its own. From
`template/dartway_starter_flutter/lib/core/update_required_page.dart`:

```dart
class UpdateRequiredPage extends ConsumerWidget {
  const UpdateRequiredPage({required this.refusal, super.key});

  /// `dw.updateRequired` or `dw.protocolUnsupported`.
  final DwCallRefusal refusal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final l10n = context.l10n;
          final updateRequired = refusal.isCode(DwCoreRefusal.updateRequired);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIconView(AppIcon.brandMark, size: 64),
                    const SizedBox(height: 24),
                    AppText.title(
                      updateRequired
                          ? l10n.updateRequiredTitle
                          : l10n.serverMismatchTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    AppText.body(
                      updateRequired
                          ? l10n.updateRequiredBody
                          : l10n.serverMismatchBody,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

**Why the project writes it.** The framework knows neither the app's language nor where the app is
published. The skeleton's page has no store button yet; once the app is in a store, the link to its
store page goes under the text.

**Without `updateRequiredScreen`** the app stays on screen and every call answers the refusal:
`dw.action` shows it through `refusalText` like any other refusal, and each read renders its error.
That is why the skeleton's `refusal_text.dart` still gives both codes a sentence — for a place that
renders a refusal on its own. With the page set, `dw.action` shows nothing for an incompatibility: the
page is already the message.

## Proven by

- `example/dartway_example_flutter/test/app/update_required_test.dart` and the last test of
  `template/dartway_starter_flutter/test/auth/sign_in_test.dart`: a fake server whose contract moved
  to a newer breaking line answers the app, which is mounted through `DwAppBootstrapper` exactly as the
  runner mounts it; the client reports `dw.updateRequired`, "Update the app" is on screen, and nothing
  of the app is.
- `packages/dartway_core_flutter/test/dw_flutter_core_test.dart` — "a build the server no longer
  supports gets the update-required screen over the app".

## Related

- [Flutter core](flutter-core.md) — `DwFlutterConfig` and the bootstrap.
- [Refusals and statuses](../2-core/refusals-and-statuses.md) — `incompatible` among the statuses.
