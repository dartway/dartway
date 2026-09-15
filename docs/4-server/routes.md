# Routes: how does a caller that is not the app reach the server?

The app calls `POST /dw/<WireName>` with a DTO. Some callers cannot: a payment provider posting a
webhook, a partner's callback, a tool that downloads a file, an MCP client. For them a project
declares **routes** — plain HTTP doors on the same port, over the framework's own small HTTP types.

```dart
final routes = <DwRoute>[
  DwRoute.get(
    '/hello',
    (ctx, request) => DwHttpResponse.json({
      'hello': request.query['name'] ?? 'world',
      'agent': request.headers['x-agent'],
    }),
  ),
  DwRoute.post('/echo', (ctx, request) async {
    final body = await request.json() as Map<String, Object?>;
    await ctx.jobs.enqueue('record', {'tag': body['tag']});
    return DwHttpResponse.json(body, status: 201);
  }),
];
```

Passed as `DwAppServer(routes: routes)`; both are from
`packages/dartway_core_server/test/routes_test.dart`.

## Declaring a route

`DwRoute.get(path, handle, {auth})`, `DwRoute.post(…)` and `DwRoute.any(…)` — every method; a
route of the same path with a specific method wins over it. The handler is a `DwRouteHandler`:

```dart
typedef DwRouteHandler =
    FutureOr<DwHttpResponse> Function(DwRouteContext ctx, DwHttpRequest request);
```

**Paths match exactly** — a map lookup, no patterns and no path parameters; an id goes in the query
or the body. An unknown path is `404`; a known path with another method is `405` with `Allow`.

The server refuses to start on a route at `/dw`, under `/dw/` or at `/health` (the framework's), on
a path that does not start with `/`, or on the same method and path declared twice.

## `DwRouteContext`

`DwRouteContext` is a `DwCallContext` ([handlers](handlers-and-context.md#dwcallcontext)):
`ctx.db`, `ctx.transaction`, `ctx.publish`, `ctx.jobs`, `ctx.accounts`, `ctx.files`, `ctx.log`. A
route may publish and enqueue jobs. It does **not** run in a transaction: `ctx.db` is the pool, so a
route that writes more than one row opens `ctx.transaction`. Publications are delivered when the
route answers.

## `DwHttpRequest` and `DwHttpResponse`

`DwHttpRequest`:

| Member | |
|---|---|
| `method` | upper case |
| `path` | without the query |
| `headers` | values by lower-case name; repeated headers joined with `,` |
| `query`, `queryAll` | query parameters; `query` keeps the last value of a repeated one |
| `bytes({maxBytes})` | the whole body, at most `maxBytes` (`DwServerSettings.maxBodyBytes` by default) |
| `text({maxBytes})` | the body as UTF-8 |
| `json({maxBytes})` | the body as JSON |

A body read fails with `DwRequestBodyException`, which answers its status when the route lets it
propagate: `413` over the limit, `408` when the body does not arrive within `bodyReadTimeout`,
`400` for bytes that are not UTF-8 or JSON. A body the route never reads is drained before the
answer, so the caller can read the answer instead of a connection reset.

`DwHttpResponse(status, {headers, body})`, `DwHttpResponse.json(value, {status, headers})`,
`DwHttpResponse.text(text, {status, headers})` and `DwHttpResponse.empty({status: 204, headers})`.
`Content-Length` is the server's to write.

## What a thrown error answers

| Thrown | Answer |
|---|---|
| `DwRequestBodyException` | its status and message, as text |
| a refusal (`ctx.refuse`, `DwRefusalException`) | `{"refusal": …}` with the status the same refusal gets on a call — `422`, or `403`/`404`/`409`/`429` (with `Retry-After`), `426` for an incompatibility |
| `DwNotAuthenticatedException` (`ctx.requireAccountId`) | `401` |
| anything else | `500` with `{"incident": "<id>"}` only, and an alert ([alerts](alerts.md)) |

An exception's text is written for the operator and may carry a query, a path or a secret; the
caller of a door never sees it.

## `DwRouteAuth`

A route reads `Authorization: Bearer <token>` — the same session keys calls carry, app and personal
alike — only when it says so:

- **`DwRouteAuth.none`** (the default) — the header is not read; `ctx.accountId` and
  `ctx.sessionKey` are `null`. For doors whose callers prove themselves another way, like a signed
  webhook, whose `Authorization` header belongs to its sender.
- **`DwRouteAuth.optional`** — a valid token signs the context in; no header leaves it anonymous.
- **`DwRouteAuth.required`** — as `optional`, and no header is `401` too.

Under `optional` and `required`, a token that is unknown or revoked is answered `401` with
`WWW-Authenticate: Bearer` before the handler runs, as on a call: a caller holding a dead token
must learn it. An `Authorization` header that is not one bearer token — another scheme, a repeated
header, two tokens folded together by a proxy — is `400`. `ctx.sessionKey?.kind` tells a personal
key made for a tool from the app ([session keys](auth-identity.md#session-keys)).

## Webhooks

A webhook is a route with `DwRouteAuth.none` that proves its caller itself:

1. read the body with `request.bytes()` — the raw bytes are what a provider signs — with a
   `maxBytes` that fits the provider's payloads;
2. verify the provider's signature header against them, and answer `401` when it does not match;
3. do the least that must happen now — typically `ctx.jobs.enqueue` with the provider's event id as
   `key` — and answer at once. Providers retry slow or failed deliveries; a job with retries and
   backoff is the place for the slow part ([jobs](jobs.md)).

A key deduplicates only while the job is pending. A delivery repeated after the job succeeded
enqueues again, so the work itself checks whether the event was already applied — against a row of
the project's, with a unique constraint on the event id.

## Where routes are reachable

In a deploy, the API domain proxies every path to the server; the app's own domain proxies only
`/dw/` and `/health`. So a webhook URL given to a provider is on the API domain
([deploy](../5-tooling/deploy.md)). In development, `dartway dev` forwards `/dw/*` and `/health`,
and a project door only when named with `--api-path /webhooks/payments`
([CLI](../5-tooling/cli.md)).

## Related

- [The application server](app-server.md) — the one port routes share with calls.
- [Alerts](alerts.md) — what a failed route reports.
