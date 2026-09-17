# dartway_analytics_server

Analytics for a DartWay server: `DwAnalyticsModule` in `DwAppServer(modules:)`.

- the app's batches stored in the project's Postgres, each event once by install and sequence;
- sessions by inactivity, installs linked to the accounts they sign in as;
- `ctx.analytics.track(event, properties:)` — events the server records in the caller's transaction;
- retention (`dw.analytics.cleanup`, 180 days by default).

Documentation: `docs/4-server/analytics.md`.
