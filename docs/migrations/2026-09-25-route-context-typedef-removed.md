---
title: "DwRouteContext is gone — a route handler's ctx is typed DwCallContext directly"
affects:
  dartway_core_server: "0.21.0-dev.6"
---

## Who is affected

A project that spells `DwRouteContext` as an explicit type — in a route handler's signature, a
helper function or an extension on it.

## What changed

`DwRouteContext` was a plain alias for `DwCallContext`: same type, same members, no signature or
behaviour difference. One way to name a route's context is kept, not two.

## What to change

Replace `DwRouteContext` with `DwCallContext` wherever it is named explicitly:

```dart
- Future<DwHttpResponse> handleWebhook(DwRouteContext ctx, DwHttpRequest request) async { ... }
+ Future<DwHttpResponse> handleWebhook(DwCallContext ctx, DwHttpRequest request) async { ... }
```

A route handler written as an inline closure (`DwHttpRoute.post('/webhook', (ctx, request) => ...)`)
needs no change: `ctx`'s type is inferred from `DwRouteHandler` either way.
