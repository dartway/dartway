# Web routes: an integration calling in

A Serverpod route that answers an outside system — a payment webhook, a
delivery callback, a partner's push — is an HTTP handler, not an endpoint. It
has no session of ours, no authenticated user, and no client library on the
other side. What it needs is always the same four things: read the body once,
log the request, decide what the caller is allowed to see when it fails, and
answer in a shape they can parse.

The framework owns all four. `DwWebServerLog` is a framework table and arrives
by migration in every project, so "integration requests are logged" is settled
upstream; `DwWebServerLogger` is what writes into it.

```dart
Future<bool> handleCall(Session session, HttpRequest request) =>
    DwWebServerLogger.handleWithExceptions(
      session,
      request,
      handler: 'PaymentCallback',
      action: (body) async {
        final payload = jsonDecode(body ?? '{}') as Map<String, dynamic>;
        final orderId = payload['orderId'];
        if (orderId == null) {
          throw const DwPublicWebException('orderId is required');
        }
        await _apply(session, orderId as int);
        return {'applied': true};
      },
    );
```

A successful `action` becomes `{"success": true, "data": …}` with `200`.

## What the caller is told when it fails

**Only a `DwPublicWebException` reaches them.** Its `message` is the response
body and its `statusCode` the status — `400` unless you say otherwise.

Anything else is answered with `500` and a fixed sentence. That is not caution
for its own sake: an arbitrary exception carries whatever it carries — a
database error carries its query, a null check carries a file path, a framework
failure carries whatever the framework felt like saying — and it was written
for us, not for a caller we never authenticated. The text is not lost; it goes
to the alert and into the `DwWebServerLog` row, where it is of use.

So "safe to show the caller" is a **type**, not a convention:

```dart
throw const DwPublicWebException('unknown signature', statusCode: 401);
```

A public failure raises no alert. The route refusing on its own terms is not an
incident, and alerting on every malformed request is how people learn to stop
reading alerts. It is still recorded in the log row.

## What reaches the log table

Headers and the JSON body are written with sensitive values replaced, walking
maps **and lists** — a payload keeps its secrets one level inside an array as
readily as under a key. A body that is not JSON is not logged at all.

`DwWebServerLogger.knownSensitiveKeys` is the maintained list (`authorization`,
`cookie`, `x-api-key`, `token`, `secret`, …). Pass `sensitiveKeys:` to extend it
for a route whose partner names things its own way — and add it to the framework
list instead when the name is not project-specific, because the next project
will meet the same partner.

The log row records the method, URL, sanitised headers and body, status, status
code, error text, duration, handler name and caller IP. Writing it never fails
the request: a failure to log is alerted and swallowed.
