---
title: Require signed Studio tokens for the web release origin
affects:
  dartway_studio_bridge: "0.12.0-dev.0"
  dartway_studio_binding: "0.4.0-dev.0"
---

## Who is affected

A web release using `DwStudioBinding` without a custom `validateAccessToken`, or
`studioSignedAccessValidator` with an empty origin. These releases now require a
signed Studio token for the current app origin.

## What to change

Configure the connecting Studio to issue tokens for the app's current origin.
Leave `STUDIO_APP_ORIGIN` unset to reuse one web image across destinations. Keep
an explicit origin only when the release intentionally accepts that fixed origin.

## How to check

Build and serve a web release. A valid token for its current origin connects;
an empty token or a token for another origin is refused. Debug/profile preview
without an explicit origin remains available for local development.
