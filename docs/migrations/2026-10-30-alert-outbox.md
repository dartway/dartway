---
title: Wire durable server alerts
affects:
  dartway_core_server: "0.25.0-dev.1"
---

## Who is affected

Every existing server project. The durable outbox is created automatically, but without this
wiring incidents only reach the server log.

## What to change

In `bin/server.dart`, pass the sink read by the framework environment to the server builder:

```dart
final server = AppServer.build(
  database: env.server.database,
  alerts: env.server.alerts,
  alertProject: env.server.project,
  alertEnvironment: env.server.environment,
  // ...
);
```

Under each deployment destination's `requires.secrets` in `deploy/config.yaml`, declare either
the HTTP receiver pair:

```yaml
requires:
  secrets:
    - DW_ALERT_HTTP_URL
    - DW_ALERT_HTTP_TOKEN
```

or the Telegram pair (and the proxy only when that deployment needs one):

```yaml
requires:
  secrets:
    - DW_TELEGRAM_ALERTS_BOT_TOKEN
    - DW_TELEGRAM_ALERTS_CHAT_ID
    - DW_TELEGRAM_ALERTS_PROXY_URL
```

## How to check

Start the server, cause a test incident, and verify that the configured receiver gets it. Run
`dartway deploy check --env <destination>` to verify the destination's required secrets.
