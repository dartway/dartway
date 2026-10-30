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
| `asyncBuild` | a read's failed branch — `DwReadBuilder`, `DwPagedListView`, `DwWindowListView` — once per failure; never a refusal, a signed-out read or an unreachable server. |
| `client` | the data client, with no caller to throw to: a server answer it could not read, a request's `onUpdate` that threw, a channel the server does not declare, a sign-out that did not revoke the key; and `dw.uploader()` for an upload failure worth an operator's attention. |
| `manual` | an explicit `dw.handleError(...)` from app code — and a plugin whose `init` failed with `blocksStartup` false. |
| `failedCall` | declared, and not used by the framework's own interception points today. |

A report is dispatched to **`DwFlutterConfig.onErrorReport`** when it is set. Without an override, `DwFlutterCore` uses its built-in persistent reporter and sends the report to the app server. A no-op callback explicitly opts out.

Set `DwFlutterConfig.uiActionFailedText` to the localized message shown when a
`uiAction` throws, so the person who pressed the button is not left without feedback.

## What a report carries

`DwErrorReport`:

- `error`, `stackTrace`, `source`;
- `label` — what failed, for any source: for `uiAction` the action's `label`, else its
  `onErrorNotification`, else its `onSuccessNotification`; for others what `handleError(label:)` named. Give an action an explicit `label` when its texts are generic: twelve reports
  labelled "Saved" say nothing;
- `failedCall` — the wire name of the request or command that failed, when the error names one
  (`DwFailedException.call`);
- `context` — a `DwErrorContextSnapshot`:

| Field | Filled from |
|---|---|
| `platform` | Flutter: `android`, `ios`, `macos`, …; `web/android`, `web/ios`, … on the web. |
| `appVersion` | `DwFlutterConfig.appVersion`. |
| `route` | the route source the app registered (below); `null` without one. |
| `featureIds` | the ids of the `DwFeatureWidget` widgets mounted on screen at that moment — see [features and specs](features-and-specs.md#where-the-spec-goes). |
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

## Delivery, offline queue and opt-out

The default reporter persists reports through the app's `DwKeyValueStorePlugin` before sending them.
At most 50 different reports are retained and the oldest drops first. Repetitions with the same error
type and first stack frame are one entry with a count. The queue survives a restart and is retried at
startup, after a successful server call, and when the app resumes.

There is not yet a direct “connectivity back” trigger. Bounded retry timers cover an offline queue;
network reachability notifications are tracked separately in [dartway#692](https://github.com/dartway/dartway/issues/692).

The public ingestion endpoint accepts anonymous startup failures. It caps the body and every field and
rate-limits both device id and peer IP. An authenticated request derives its account from the session;
report content is untrusted and remains plain text. Accepted reports become `DwServerIncident`s and use
the server's existing alert ceilings, durable outbox, and coalescing.

Set `onErrorReport` to replace the built-in reporter. For example, a no-op explicitly opts out:

```dart
DwFlutterConfig(
  onErrorReport: (_) {},
  // ...
)
```

A custom callback owns the complete policy. Refusals and expired authentication still reach it, so a
callback should normally ignore those expected answers rather than alerting on them.

## Related

- [Actions and refusal texts](actions-and-refusal-texts.md) — what an action shows before it reports.
- [Flutter core](flutter-core.md) — `DwFlutterConfig` and `DwAppRunner`.
- [Alerts](../4-server/alerts.md) — the server's side of failures.
