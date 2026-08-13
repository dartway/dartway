## 0.1.0

First release of the app half of DartWay push, reached as `dw.plugins.push`.

- **Transport selection by declaration order.** The first provider that builds for the platform and
  answers for itself on the device wins, so `[DwRuStorePush(), DwFirebasePush()]` means RuStore on
  Android and FCM everywhere else — with no platform switch in the plugin.
- **Token lifecycle.** A token and a signed-in user arrive independently and in either order; the
  plugin sends the pair once, resends after a refresh or a change of user, catches up when either
  changed mid-flight, and survives being offline. Registration goes through the module's CRUD
  action, or through a callback of your own.
- **Taps that arrive exactly once.** A cold-start notification is held until the app can route it,
  then delivered after a frame the plugin asks for itself — a tap changes no widget, so nothing
  else would schedule one and the navigation would land on an unrelated gesture minutes later.
- **Permission on the app's terms** — on attach by default, or on demand at a moment the user
  understands.
- **`DwPushScope`** drives all of it from the widget tree, following the recipient through a
  Riverpod listenable.
