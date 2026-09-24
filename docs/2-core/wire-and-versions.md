# What travels on the wire, and what happens when it changes?

Most of the time nobody reads this: the generated codecs, `DwAppServer` and the client agree by
construction, because both sides use the declarations in `dartway_core_shared`
(`packages/dartway_core_shared/lib/src/protocol/`). It matters when something else speaks to the
server — a tool, a test, a proxy — and when the framework or the app changes under a build already
installed on someone's phone.

## Three paths

`DwHttpContract` declares them once for both sides:

```
POST /dw/<WireName>   a request or a command; the body is the DTO's JSON
GET  /dw/live         the WebSocket of live updates
GET  /health          liveness and database reachability
```

`/dw/` and `/health` are reserved: a project route under them fails the server's startup
([../4-server/routes.md](../4-server/routes.md)).

## A call

- **POST only.** A request is a read, but its parameters are a DTO body, and one method keeps one code
  path. Any other method is a malformed call (400).
- **The body is the DTO's own JSON** — no envelope, no type tag: the path names the type.
  `Content-Type` is `application/json` in UTF-8; anything else is a malformed call.
- **The body limit** is `DwServerSettings.maxBodyBytes`, 1 MiB by default; a handler may set its own
  `maxBodyBytes`. A larger body is a malformed call.
- A header sent twice is a malformed call: which of two tokens or two keys was meant cannot be guessed.

| Header | |
|---|---|
| `Authorization: Bearer <token>` | absent for an anonymous call |
| `Dw-Protocol: <dwProtocolVersion>` | required on every call |
| `Dw-App-Version: <semver>+<build>` | the app build (`DwAppVersion`), e.g. `1.4.2+87` |
| `Dw-Idempotency-Key` | required on a command, forbidden on a request; at most 128 characters |
| `Dw-Live-Connection` | optional: the id of the caller's live socket ([channels-and-realtime.md](channels-and-realtime.md)) |
| `Retry-After` | on a `429` answer, whole seconds |

Query parameters exist only for the kinds whose position is not part of their key:

| Kind | Parameters |
|---|---|
| `DwPageRequest` | `offset`, `pageSize` |
| `DwWindowRequest` | at most one of `anchor`, `before`, `after` (cursors), and `pageSize` |
| every other kind, every command | none — a table's `page` and `pageSize` are fields in the body |

A parameter the kind does not take, a repeated one or a count not written canonically (`07`, `+7`) is
a malformed call.

## The answer

The body is always one of five shapes, and the HTTP status is a function of it
([refusals-and-statuses.md](refusals-and-statuses.md)):

```json
{"status":"ok","result":<encoded by the call's class>,"updates":{"bookings:7":{"SessionBooking":[…]}}}
{"status":"refused","refusal":{"code":"messageTooLong","params":{"max":"4000"},"field":"text"}}
{"status":"unauthenticated"}
{"status":"failed","incidentId":"…"}
{"status":"incompatible","refusal":{"code":"dw.updateRequired"}}
```

- `result` is untagged — its type is the call's — and omitted when `null`.
- `updates` is what the command published, grouped by channel and then by wire name, and omitted
  when empty. It is the only place a type name stands next to objects; a deletion travels in the
  `DwDeletedObject` group as `{"type": "SessionBooking", "id": 9}`.
- `"replayed": true` marks an answer repeated for an idempotency key.
- A failed answer adds `"failure": "malformedCall"` or `"unknownCall"` for the 400 and 404 cases.
- A refusal's `params` and `field` are omitted when empty.

## The live socket

The client opens `GET /dw/live?protocol=<version>&app=<semver+build>` — query parameters, because a
browser cannot set headers on a WebSocket upgrade. Calls never travel here; the socket carries only
what HTTP cannot:

```
← {"k":"hello","connection":"<id>"}                  on open
→ {"k":"auth","token":"…"} / {"k":"auth"}            first, and after sign-in and sign-out
← {"k":"authed","account":7} / {"k":"authed","rejected":true} / {"k":"authed"}
→ {"k":"sub","ch":"bookings:7"} / {"k":"unsub","ch":"…"}
← {"k":"subok","ch":"…"} / {"k":"subno","ch":"…", …}
← {"k":"upd","ch":"schedule","updates":{"ClubSession":[…]}}
← {"k":"closed","ch":"…"}
```

A `subno` carries a refusal (`r`), an incident id (`x`), or neither — not authenticated. The server
closes the socket with a `DwCloseCode`:

| Code | Why | The client |
|---|---|---|
| 1001 | server stopping | reconnects |
| 1011 | server failure; reason `dw.failed:<incident>` | reconnects |
| 4008 | slow consumer: its outbound queue passed `outboundLimitBytes` | reconnects with growing backoff |
| 1003, 1009, 4000 | a binary frame, a message over `maxLiveMessageBytes`, a message that does not parse | reports it and backs off |
| 4026 | incompatible; reason `dw.updateRequired` or `dw.protocolUnsupported` | stops for good |

The server pings every socket every 20 seconds (`pingInterval`) and drops a peer that has not
answered by the next ping.

## Versions

Two versions decide whether a build may talk to a server, and both are checked before anything else
about a call — an incompatible client learns that first, whatever else it got wrong.

**`dwProtocolVersion`** is the version of the framework's wire. The client sends it as `Dw-Protocol`
(and `?protocol=` on the socket). A missing header is a malformed call; another version is answered
`426` with `dw.protocolUnsupported`, and the socket closes with 4026. It means a framework version skew
between app and server, which the operator resolves.

**`Dw-Contract-Version`** is the version of the project's contract the app was compiled with — the
shared package's `version:`, written by `dart run dartway_cli:dartway generate` into the protocol both sides are built
with (`DwWireProtocol.contractVersion`), and sent as `?contract=` on the socket. Semantic versioning
decides compatibility: a change that removes or renames anything an installed app sends or reads
raises the **breaking line** — the major version, or the minor one below 1.0 — and anything additive
does not. A client of an older line than the server's, or one that sends none, is answered `426`
with `dw.updateRequired`. That is the lever for a project's own incompatible change: a renamed field
of a project DTO is not a protocol change, and old builds are turned away by the version raised in the
same pull request — nothing to remember in an environment at deploy time (#296). A client of a newer
line is not refused; the server is the one behind.

**`Dw-App-Version`** is the app's own build, from `DwFlutterConfig.appVersion`. It labels the session
key a sign-in makes, and decides nothing.

**On the client an incompatibility is terminal.** The first `426` (or close 4026) sets
`dw.incompatibility`; from then on every call is answered locally with that refusal, the socket stays
closed, and `DwFlutterConfig.updateRequiredScreen` replaces the app — see
[../3-flutter/update-required.md](../3-flutter/update-required.md).

## Origins

**Calls are same-origin by deployment, and the server sends no CORS headers — also in development
(D-039).** In production the web app's host proxies `/dw/` and `/health` to the server
([../5-tooling/deploy.md](../5-tooling/deploy.md)); locally `dart run dartway_cli:dartway dev` does the same
([../5-tooling/cli.md](../5-tooling/cli.md)). A cross-origin browser call cannot get through anyway:
a JSON body needs a preflight, and the server never answers one. Native apps send no `Origin` and are
unaffected.

The live socket checks `Origin` itself, since browsers do not preflight an upgrade. It is accepted when
its host and port are the ones the upgrade was sent to (`Host` carries no scheme, so the scheme is
not compared), or when it is listed in `DwServerSettings.allowedOrigins` — full origins such as
`https://app.example.com`, compared by scheme, host and port. The server refuses to start with an
entry that is not a full origin: a bare host would silently allow every port and scheme of it. An
upgrade without `Origin` (a native app) is allowed; an `Origin` that does not parse, such as `null`
from a sandboxed page, is refused.

## A wire change is a protocol change (D-052)

An app build on a phone keeps speaking the wire it was compiled with. If the framework changes how a
call, an `ApiResponse`, an update transport, a live message or generated DTO JSON looks on the wire,
that build gets no compile error — it gets a body it cannot decode, and its user a broken screen. The
protocol version is what turns that into an honest "update the app".

So **any such change bumps `dwProtocolVersion`**, in the same change. The rule is enforced by
`packages/dartway_core_shared/test/wire_golden_test.dart`: it encodes every shape as the framework
does, compares it with the encodings recorded in `test/goldens/wire_golden.dart` together with the
protocol version they were taken at, and decodes each recorded encoding again, so a reader that stops
accepting an encoding it accepted before is a wire change too. When an encoding differs while the version is
unchanged, the test fails with the instruction: bump `dwProtocolVersion` and refresh the golden with
`DW_UPDATE_GOLDENS=1 dart test test/wire_golden_test.dart`. A refresh refuses to overwrite a recorded
encoding while the version is still the one it was recorded at — it follows a bump, it does not
replace one.
