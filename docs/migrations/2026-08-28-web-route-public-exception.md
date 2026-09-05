---
title: "A web route no longer answers the caller with the exception text"
affects:
  dartway_serverpod_core_server: "0.12.0"
---

## Who is affected

A project with web routes going through `DwWebServerLogger.handleWithExceptions` — webhooks,
callbacks, anything a foreign system calls.

`handleWithExceptions` used to catch everything and write `e.toString()` into the response body. An
arbitrary exception carries what it carries: a database error carries its query, a null check
carries a file path. All of it was written for us, and whoever called a webhook is not somebody we
authenticated. The `500` looked ordinary from the outside, so nothing ever drew attention to what
had been sent with it.

Now everything answers with a fixed sentence and `500`; the real text goes to the alert and the
`DwWebServerLog` row. **Nothing breaks, and the change is silent** — which is why this note exists:
a caller that was relying on the message is now getting the fixed sentence instead, and nobody on
this side will see that happen.

## What to change

Go through the routes and find every refusal that was *meant* for the caller — a missing
parameter, a bad signature, an unknown id. Each of those becomes a `DwPublicWebException`, whose
message and status code go out verbatim and which raises no alert, because a route refusing on its
own terms is not an incident:

    - throw Exception('orderId is required');
    + throw const DwPublicWebException('orderId is required');

    - throw Exception('unknown signature');
    + throw const DwPublicWebException('unknown signature', statusCode: 401);

Leave everything else as it is. An unexpected failure answering with a fixed sentence is the point
of the change, not a regression.

## How to check

Call each route with the input that makes it refuse, and read the response body: a refusal you
meant the caller to see says what it always said; anything else says the fixed sentence, and the
detail is in the alert and the `DwWebServerLog` row.

While there: a secret nested inside a **list** used to reach the log row intact — the sanitiser
walked maps and stopped. It is fixed, and no project action is needed, but a log row written before
this may still hold one.
