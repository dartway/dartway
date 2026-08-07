## 0.1.0

Initial release, alongside `dartway_push_server` 0.1.0.

The package carries the generated protocol of the DartWay push module and nothing else — push
models are server-only. It exists because a Serverpod module needs a client package and the
generated protocol of an app that uses the module imports it.
