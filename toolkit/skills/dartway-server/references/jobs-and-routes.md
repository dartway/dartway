## 7. Jobs, routes

**A job belongs to a feature**: kinds and definitions in `<feature>_jobs.dart`, declared by
`DwServerFeature(jobs: invoicesJobs)`. Names: the kinds class `InvoicesJobs`, the list `invoicesJobs`,
a job `'invoices.mark_overdue'` (`dw.` names are the framework's).

```dart
abstract final class InvoicesJobs {
  static const remind = DwJobKind<({int invoiceId})>(
    'invoices.remind',
    encode: _encode,
    decode: _decode,
  );
  static Map<String, Object?> _encode(({int invoiceId}) p) => {'invoiceId': p.invoiceId};
  static ({int invoiceId}) _decode(Map<String, Object?> json) => (invoiceId: json['invoiceId']! as int);
}

final invoicesJobs = <DwJobDefinition>[
  DwQueuedJob(InvoicesJobs.remind, handle: (ctx, p) async {
    final invoice = await ctx.db.invoices.findById(p.invoiceId); // decided when it runs
    if (invoice == null || invoice.status == InvoiceStatus.paid) return;
    // …
  }),
  DwRecurringJob('invoices.mark_overdue', every: const Duration(hours: 1), handle: (ctx) async {/* … */}),
];
```

The payload is spelled as a map once, in the kind's codec — never `payload['x']! as int` in a handler.
A command enqueues by the kind — `ctx.jobs.enqueue(InvoicesJobs.remind, (invoiceId: id), runAt: …,
key: …)` — which joins its transaction (`key` deduplicates pending jobs). A queued job is transactional by default; with
`transactional: false` (it calls a service) it may run twice after a crash. A job has no caller, reads
its state when it runs, may publish, and is due by the server's clock. Worked example, in the framework repository's example (on GitHub, not in this project):
[`bookings_jobs.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/bookings/bookings_jobs.dart).

**A `DwHttpRoute` is for callers that cannot speak the contract** — a webhook, a download link. In
`<feature>_routes.dart`, registered in `DwServerFeature(routes: [...])`, exact paths (`/dw/…` and
`/health` are the framework's). Identifiers go in the query or body. Routes are
reached on the API host; the app host forwards only `/dw/`, so a Flutter page
may use the same path as a server route.
`auth:` defaults to `DwRouteAuth.none` — the route verifies its sender
itself (a signature); `optional`/`required` read an `Authorization: Bearer` key like a call. A door acting for a signed-in
person runs the call in process — `server.callAs(call, token:, idempotencyKey:)` — never over its own
port. A route that rejects silently names the step that turned the request away with an enum value
(`foreignOrigin`, `versionMismatch`, `unknownType`), never a boolean, and carries no payload or secret.
