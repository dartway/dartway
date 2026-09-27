# dartway_analytics_shared

The analytics contract shared by a DartWay server and its app: `DwAnalyticsEvent` (the mixin of a
project's event enum), `DwAppEvent` (the events the framework records), and `DwTrackEvents` — the
batch the app sends, with its limits — and the reads of what was recorded: `DwGetAnalyticsReport`,
`DwGetAnalyticsCatalog` and the dashboard calls. Compose `dwAnalyticsProtocolEntries` into the protocol.

Documentation: `docs/4-server/analytics.md`.
