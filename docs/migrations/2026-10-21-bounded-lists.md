---
title: Bound whole lists and the reads behind them
affects:
  dartway_core_server: "0.23.0-dev.1"
  dartway_cli: "0.26.0-dev.1"
---

## Who is affected

Every project with a `DwListRequest`. Nothing breaks in production: a list answered past its
request's `maxItems` (200 unless the class names another) is served whole there, with a warning in
the server log. Two things are new to see:

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
   - a list the domain bounds reads one past its bound, so the server still notices it outgrowing it:

         ctx.db.<table>.find(where: …, orderBy: …, limit: request.fetchLimit)

   - a read the domain keeps small that is not a list's answer says why, beside the read:

         ctx.db.<table>.find(where: …, unbounded: 'a board has a handful of columns')

3. A list that legitimately holds more than 200 items raises its bound in its class, with the reason
   in one line of its doc comment:

       /// … At most 500: a club schedules about three weeks ahead.
       const ListUpcomingSessions({required this.from}) : super(maxItems: 500);

## How to check

`dart run dartway_cli:dartway check --type unboundedRead` from `<project>_flutter` reports nothing,
and `dartway test` is green. A server started with `bin/server.dart` logs no
`answered … items, past its bound` and no `(largeResponseBytes)` warning for the project's own
screens; a production log that shows either names the request to page.
