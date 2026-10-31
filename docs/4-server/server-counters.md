# Server counters

The app server keeps inexpensive call counters in memory for DartWay Studio. It retains the last
hour of minute buckets; a restart may lose the open minute. History, norms, thresholds and
incidents belong to Studio, not the app. Host CPU, memory, disk and PostgreSQL connections are not
reported here.

## Configuration

Put a long random token in the project's deploy secrets as `DW_STUDIO_READ_TOKEN`, add that name to
the destination's `requires.secrets`, and pass the environment value into the server settings:

```dart
DwServerSettings(
  studioReadToken: env.server.studioReadToken,
  keyActions: {CreateOrder, CompleteCheckout},
)
```

`DwServerEnvironment.read` reads the token without project-specific parsing. With no token the
endpoint remains unavailable. Replacing or removing the deploy secret revokes the old token when
the new server starts.

## Read contract

Studio sends `GET /dw/server-counters` with `Authorization: Bearer <DW_STUDIO_READ_TOKEN>`. A missing,
wrong or revoked token receives `401`; the endpoint never accepts a user session token. The optional
`cursor` query parameter is an ISO-8601 minute returned by an earlier response. The response contains
all retained, closed minutes strictly after it. Studio should persist the returned `cursor` only
after persisting the response.

```json
{
  "minutes": [
    {
      "minute": "2026-10-31T12:04:00.000Z",
      "endpoints": {
        "CreateOrder": {
          "calls": 100,
          "errors": 3,
          "keyAction": true,
          "responseTimeMs": {"p50": 18.25, "p95": 61.7, "max": 109.4}
        }
      }
    }
  ],
  "cursor": "2026-10-31T12:04:00.000Z",
  "jobQueue": {"waiting": 7, "failed": 2}
}
```

An error is a call answered with a `5xx` status. Response times are milliseconds from request arrival
through encoding the answer; p50 and p95 use nearest-rank percentiles. `jobQueue` is the current
database-backed queue snapshot: waiting rows have not exhausted their attempts, while failed rows
have. Empty minutes are omitted. The cursor still advances across them, so polling after ten minutes
returns every non-empty closed bucket among those ten and does not replay an already acknowledged
minute.
