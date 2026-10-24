---
title: Bound whole lists and the reads behind them
affects:
  dartway_core_shared: "0.23.0"
  dartway_core_server: "0.23.0"
  dartway_cli: "0.26.0"
---

## Who is affected

Every project with a `DwListRequest`. Its new inherited `maxItems` member can collide with a
project's existing request field of that name (see step 4). A whole-list handler using `readWhole`
serves all rows in production, warning past its bound (200 unless the class names another).
Two things are new to see:

- **a server test** whose `list` handler answers more than `maxItems` items now fails the call:
  `DwTestServer` is strict about the bound;
- **`dartway check`** warns `unboundedRead` for a repository `find(…)` in a request handler of a
  `*_handlers.dart` that names neither `limit:` nor `unbounded:`.

## What to change

1. Make a development server as strict as the tests. In `deploy/config.yaml`, under `local`:

       + DW_STRICT_BOUNDS: true

   and pass it to the settings in `<project>_server/bin/server.dart`:

         settings: DwServerSettings(
           …
       +   strictBounds: env.server.strictBounds,
         ),

2. For each `unboundedRead` warning, decide what the read is:
   - a list that grows with use — tasks, messages, history — becomes a `DwPageRequest`,
     `DwTableRequest` or `DwWindowRequest` (the `dartway-contract` skill, `requests.md`);
   - every list the domain bounds reads through the server helper:

         request.readWhole((limit) =>
           ctx.db.<table>.find(where: …, orderBy: …, limit: limit))

     Apply the nullable `limit` to the same query; null means no limit. The callback only reads
     and may run twice. The normal read probes with `fetchLimit` (`maxItems + 1`). Overflow throws
     in tests and strict development, naming the request and observed probe count. Production
     re-reads once without a limit, serves all rows and logs the true count and size through the
     existing throttled warning. Do not return a `fetchLimit` probe as the answer: that truncates.

   - a read the domain keeps small that is not a list's answer says why, beside the read:

         ctx.db.<table>.find(where: …, unbounded: 'a board has a handful of columns')

3. A list that legitimately holds more than 200 items raises its bound in its class, with the reason
   in one line of its doc comment:

       /// … At most 500: a club schedules about three weeks ahead.
       const ListUpcomingSessions({required this.from}) : super(maxItems: 500);

4. If a project request already declares a field named `maxItems`, rename that field and its
   constructor argument to a domain name such as `resultLimit`. Update call sites, handler reads,
   validation and tests, then run `dartway generate` to regenerate codecs and the project contract
   descriptor. Keep the inherited `maxItems` for the framework bound, passed through `super`.
   This project-field rename changes the project's JSON contract: advance its shared package's
   breaking version line and deploy matching app and server using the normal contract procedure.
   Do not override `maxItems` with a client-supplied field or hand-edit generated files. The
   framework runtime wire and `dwProtocolVersion` are unchanged.

## How to check

`dartway check --type unboundedRead` from `<project>_flutter` reports nothing,
and `dartway test` is green. A server started with `bin/server.dart` logs no
`answered … items, past its bound` and no `(largeResponseBytes)` warning for the project's own
screens; a production log that shows either names the request to page.
