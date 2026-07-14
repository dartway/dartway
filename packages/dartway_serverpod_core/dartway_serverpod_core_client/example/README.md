# Example — the package you do not write against

This is the **generated** Serverpod client of the DartWay core module: protocol models and endpoint
callers. It is not edited by hand, and you do not call it directly.

You depend on it because
[`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter) does, and
that is the package you actually use:

```dart
// What you write:
ref.watchModelList<Booking>();
DwRepository.saveModel(booking);

// What this package carries underneath: the wire types (DwApiResponse,
// DwModelWrapper, DwBackendFilter) and the generated endpoint callers.
```

## Where it comes from

The DartWay core is a Serverpod **module**. Your app registers it in `config/generator.yaml`:

```yaml
modules:
  dartway_serverpod_core:
    nickname: dartway
```

`serverpod generate` then merges the module's protocol into your app's own generated client, which
is how a typed `Booking` travels from your Postgres table to your widget without you writing a DTO.

The one thing worth knowing: `DwApiResponse<T>` is generic on the wire, so its deserialization is
resolved by hand rather than by the generated type switch. If a CRUD call ever fails to deserialize
after a regeneration, that is the place to look.
