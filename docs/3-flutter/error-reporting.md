# Where does an error in the app go, and what does the report carry?

A web stack trace is minified noise — `main.js` all the way down — and a mobile one names a widget
three layers below the cause. What makes an error report from a running app actionable is **the state
of the app when it happened**: the route, the features on screen, the action that was pressed, the
call that failed, the build and the account.

So every error the framework intercepts goes through one pipeline, and arrives at one hook the app
owns, carrying that state.

This page is the app side. Failures on the server — incidents, their ids, alert sinks — are
[alerts](../4-server/alerts.md).

## One pipeline

Every interception point calls `dw.handleError(error, stackTrace, source: ...)`, which captures a
context snapshot and dispatches a `DwErrorReport`. `DwErrorSource` names where it was caught:

| `DwErrorSource` | Caught by |
|---|---|
| `zone` | `DwAppRunner`'s global handlers — `FlutterError.onError` and the platform dispatcher's `onError` — for anything uncaught, and an app initializer that threw at start. |
| `uiAction` | `dw.action`, for a callback that threw or a result that was not a success. |
| `asyncBuild` | the error branch of `dwBuildAsync` / `dwBuildListAsync`. |
| `client` | the data client, with no caller to throw to: a server answer it could not read, a request's `onUpdate` that threw, a channel the server does not declare, a sign-out that did not revoke the key; and `dw.uploader()` for an upload failure worth an operator's attention. |
| `manual` | an explicit `dw.handleError(...)` from app code — and a plugin whose `init` failed with `blocksStartup` false. |
| `failedCall` | declared, and not used by the framework's own interception points today. |

A report is dispatched to **`DwConfig.onErrorReport`** when it is set. Without it, the report is printed
with `debugPrint` and goes nowhere else — an app that ships without a policy has no error reporting.

## What a report carries

`DwErrorReport`:

- `error`, `stackTrace`, `source`;
- `actionLabel` — for `uiAction`: the action's `label`, else its `onErrorNotification`, else its
  `onSuccessNotification`. Give an action an explicit `label` when its texts are generic: twelve reports
  labelled "Saved" say nothing;
- `failedCall` — the wire name of the request or command that failed, when the error names one
  (`DwFailedException.call`);
- `context` — a `DwErrorContextSnapshot`:

| Field | Filled from |
|---|---|
| `platform` | Flutter: `android`, `ios`, `macos`, …; `web/android`, `web/ios`, … on the web. |
| `appVersion` | `DwConfig.appVersion`. |
| `route` | the route source the app registered (below); `null` without one. |
| `featureIds` | the ids of the `DwFeature` widgets mounted on screen at that moment — see [features and specs](features-and-specs.md#where-the-spec-goes). |
| `entries` | app-defined entries. `DwFlutterCore` registers `account` — the signed-in account id — itself. |

## Making the context rich

The framework has no access to the app's router, so the app registers a lazy route source once. From
`example/dartway_example_flutter/lib/core/router/router.dart`:

```dart
dw.errorContext.registerRouteSource(() {
  final configuration = router.router.routerDelegate.currentConfiguration;
  return configuration.isEmpty ? '/' : configuration.uri.path;
});
```

Custom entries join every report: `dw.errorContext.set('tenant', 'acme')` for a value, or
`dw.errorContext.register('cart', () => cart.id)` for one read at the moment of the error (`null` leaves
it out). Every source runs guarded: a provider that throws is skipped, and can never break error
reporting itself.

## The policy is the app's

`onErrorReport` decides what an error *is*. The skeleton's, in `lib/core/dw_core.dart` (the example has
the same):

```dart
void _onErrorReport(DwErrorReport report) {
  if (report.error case DwRefusalException() || DwNotAuthenticatedException()) {
    return;
  }
  if (report.source == DwErrorSource.uiAction) {
    dw.notify.error(appL10n.actionFailed);
  }
  debugPrint(
    '[${report.source.name}] ${report.error} '
    '(route: ${report.context.route}, ${report.context.entries})\n'
    '${report.stackTrace}',
  );
}
```

Three decisions, each worth keeping when the `debugPrint` is replaced by a real sink:

- **A refusal is not an incident.** The server said no to this user, and the user has already been told
  in words through `refusalText`. Sent to an alert channel, refusals drown it: a rule doing its job twenty
  times a day is how a channel stops being read.
- **Not authenticated is not an incident.** The session ended — the key was revoked, the account is gone —
  and the sign-in screen is the message. Inside `dw.action` the app has already signed out.
- **A failed action is told to the user.** A command that timed out or failed on the server would
  otherwise end in silence: `dw.action` shows `onErrorNotification` only when the call site wrote one.

Both skipped cases still *reach* the hook — the framework reports everything, and the policy sorts it by
type, never by message. An app that wants to count refusals can.

## Related

- [Actions and refusal texts](actions-and-refusal-texts.md) — what an action shows before it reports.
- [Flutter core](flutter-core.md) — `DwConfig` and `DwAppRunner`.
- [Alerts](../4-server/alerts.md) — the server's side of failures.
