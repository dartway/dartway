# dartway_serverpod_core_server

The server side of the [DartWay](https://dartway.dev) core — a
[Serverpod](https://serverpod.dev) module that turns model definitions into a
production-ready backend:

- **Generic model-driven CRUD** — `getOne` / `getList` / `save` / `delete` /
  realtime `subscribe` for any model, no hand-written endpoints. One
  `DwCrudConfig<T>` per model declares the whole behavior:
  `allowSave` → `validateSave`, then `beforeSaveTransaction` → write →
  `afterSaveTransaction` inside one transaction, then `afterSaveTransform` and
  `afterSaveSideEffects` outside it; access filters for reads, ordering,
  includes. (Guards run before the transaction opens — a check that must not
  race belongs in `beforeSaveTransaction`.)
- **Secure by design** — reads go through explicit `accessFilter`s, writes
  through `allowSave`/`validateSave`; a model without a config is not exposed.
- **Phone auth** — passwordless flow (phone + one-time code) built on the
  app's own user model: the framework never owns your `UserProfile`.
- **Cloud storage** — S3/MinIO-compatible file storage helpers.
- **Alerts** — error reports to Telegram with structured context (see
  `dartway_serverpod_core_shared`).

## Installing the module

The package is a Serverpod **module** (nickname `dartway_serverpod_core`).
In your server package:

1. Add the dependency:

```yaml
dependencies:
  dartway_serverpod_core_server: ^0.1.0
```

2. Register the module in your `config/generator.yaml`:

```yaml
modules:
  dartway_serverpod_core:
    nickname: dartway
```

3. Run `serverpod generate` — the module's models and endpoints join your
   protocol. Module migrations ship with the package and are applied by the
   regular `--apply-migrations` flow.

4. Configure your models' CRUD in one place:

```dart
final newsPostCrudConfig = DwCrudConfig<NewsPost>(
  table: NewsPost.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null, // public read — explicit
    defaultOrderByList: [Order(column: NewsPost.t.createdAt, orderDescending: true)],
  ),
  saveConfig: DwSaveConfig<NewsPost>(
    // `isStaffMember` is a one-line extension on Session in *your* app: the
    // framework ships `session.currentUserProfileId` and `session.isUser(id)`,
    // and never owns your roles.
    allowSave: (session, ctx) async => await session.isStaffMember,
    validateSave: (session, ctx) async =>
        ctx.currentModel.title.trim().isEmpty ? 'Title is required' : null,
  ),
);
```

## The DartWay stack

| Package | Role |
|---|---|
| `dartway_serverpod_core_server` | this package — the Serverpod module |
| [`dartway_serverpod_core_client`](https://pub.dev/packages/dartway_serverpod_core_client) | generated protocol client |
| [`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter) | Flutter data layer (`watchModelList`, sessions, alerts) |
| [`dartway_serverpod_core_shared`](https://pub.dev/packages/dartway_serverpod_core_shared) | pure-Dart shared layer |
| [`dartway_flutter`](https://pub.dev/packages/dartway_flutter) | Flutter app shell: bootstrap, guarded actions, notifications |

See the canonical example app in the
[DartWay monorepo](https://github.com/dartway/dartway) (`example/`) — a full
fitness-club product built on this stack.
