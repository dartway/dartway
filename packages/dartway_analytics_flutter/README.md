# dartway_analytics_flutter

Analytics for a DartWay app, reached as `dw.plugins.analytics`:
`track(ProjectEvent.x, {'key': value})` records without a call; events wait on the device and go
to the server in batches — on an interval, at a batch size, when the app goes to the background.
The app's opening (with attribution), resuming, backgrounding and account changes are recorded by
the plugin.

Documentation: `docs/4-server/analytics.md`.
