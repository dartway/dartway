## 0.2.0

The package stops being empty: it now carries `DwPushTokenRegistration`, the
request a device sends to register its push token or hand it back. The server
half handles it through a CRUD action config an app declares
(`dwPush.tokenRegistrationConfig()`), so neither side needs an endpoint of its
own. Released alongside `dartway_push_server` 0.2.0.

## 0.1.0

Initial release, alongside `dartway_push_server` 0.1.0.

The package carries the generated protocol of the DartWay push module and nothing else — push
models are server-only. It exists because a Serverpod module needs a client package and the
generated protocol of an app that uses the module imports it.
