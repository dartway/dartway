# Quick Start

> Goal: a running fullstack Dart app in ten minutes, and your first feature — database to live
> screen — in twenty more. No endpoints are written anywhere in this guide.

## Prerequisites

- Dart SDK ^3.11 / Flutter ^3.41 (FVM recommended, see `.fvmrc`)
- Docker (Postgres)
- The Serverpod CLI (`dart pub global activate serverpod_cli`) — you need it once you add your own
  models

## 1. Create the project

```bash
dart pub global activate dartway_cli
dartway create my_app
```

You get three packages — `my_app_server`, `my_app_client` (generated), `my_app_flutter` — plus the
AI toolkit in `.claude/`.

What is inside is a **skeleton, not somebody's product**: passwordless phone auth, a `UserProfile`
with roles, navigation with zone guards, an admin panel (users + settings), a UI kit as source you
own, theming, localization, error reporting with app context. Zero domain models — your domain is
the part you write.

## 2. Run it

```bash
cd my_app/my_app_server
docker compose up -d                       # Postgres
dart bin/main.dart --apply-migrations      # schema
dart bin/seed_dev.dart --mode development  # one user per role
```

In another terminal:

```bash
cd my_app/my_app_flutter
flutter run
```

Sign in with `79990000003` (the seeded client). The one-time code is printed to the server console —
in development nothing is sent over SMS.

The home screen reads the app name from the database through the generic CRUD. Open the admin panel
as `79990000001`, change it, and watch the home screen update **without a reload**. That is the whole
path — Postgres → access config → typed live list → widget — proving itself on the first screen.

## 3. Declare a model

Models are Serverpod `.spy.yaml` files. Create `my_app_server/lib/src/models/note/note.spy.yaml`:

```yaml
class: Note
table: note
fields:
  authorProfile: UserProfile?, relation
  text: String
  createdAt: DateTime
```

The relation gives you both `note.authorProfile` (when included) and `note.authorProfileId` — the
id is what you write, the object is what you read.

Generate the code and the migration:

```bash
cd my_app/my_app_server
serverpod generate
serverpod create-migration
dart bin/main.dart --apply-migrations
```

## 4. Configure CRUD — instead of writing endpoints

One config per model. It declares the whole behaviour of the feature: who may read it, who may write
it, what counts as valid, and what happens inside the write transaction.

`my_app_server/lib/src/crud/note_crud_config.dart`:

```dart
final noteCrudConfig = DwCrudConfig<Note>(
  table: Note.t,
  getListConfig: DwGetModelListConfig(
    // Everyone signed in reads the notes. Returning null means "no filter" —
    // an explicit decision, not an oversight.
    accessFilter: (session) async => null,
    include: Note.include(authorProfile: UserProfile.include()),
    defaultOrderByList: [Order(column: Note.t.createdAt, orderDescending: true)],
  ),
  saveConfig: DwSaveConfig<Note>(
    // Who may write at all.
    allowSave: (session, ctx) async =>
        await session.isUser(ctx.currentModel.authorProfileId),

    // The business rule. Returning a string rejects the write, and the string
    // reaches the user — the rule lives here and the client cannot forget it.
    validateSave: (session, ctx) async =>
        ctx.currentModel.text.trim().isEmpty ? 'The note is empty' : null,

    // Runs inside the same transaction as the write. It can reject too —
    // return a string — which is where a rule about a shared count belongs:
    // `validateSave` runs before the transaction opens, so two concurrent
    // saves can both pass it. Nothing to reject here, hence `null`.
    beforeSaveTransaction: (session, ctx) async {
      if (ctx.isInsert) {
        ctx.currentModel = ctx.currentModel.copyWith(createdAt: DateTime.now());
      }
      return null;
    },
  ),
);
```

Register it in `lib/src/dartway/dartway_core.dart`:

```dart
dw = DwCore.init<UserProfile>(
  userProfileTable: UserProfile.t,
  userProfileInclude: UserProfile.include(),
  crudConfigurations: [
    userProfileCrudConfig,
    appSettingCrudConfig,
    noteCrudConfig, // <- here
  ],
  // ...
);
```

That is the backend. `getOne`, `getList`, `save`, `delete`, filters, pagination and realtime
subscriptions are now served for `Note` by the generic endpoint.

> **Secure by default:** a model with no config in this list is not reachable at all. You grant
> access; you never forget to take it away.

## 5. Show it, live

```dart
class NotesList extends ConsumerWidget {
  const NotesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<Note>().dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (notes) => ListView(
            children: [for (final note in notes) NoteCard(note: note)],
          ),
        );
  }
}
```

No repository, no service, no provider, no API client. The list is typed, paginated, and rebuilds by
itself when anyone writes a `Note` anywhere — open the app in two windows and watch.

Writing goes through the repository, guarded by the action:

```dart
AppButton.primary(
  'Save',
  onTap: DwUiAction.create(
    (context) => DwRepository.saveModel(
      Note(authorProfileId: myProfileId, text: text, createdAt: DateTime.now()),
    ),
    onSuccessNotification: 'Saved',
  ),
)
```

A double tap does not create two notes; if `validateSave` rejects the write, its message reaches the
user as a notification.

## Where to go next

- **[`example/`](https://github.com/dartway/dartway/tree/master/example)** — a complete application
  built exactly this way: a fitness club with a schedule, bookings with capacity rules, a staff-only
  chat invisible to clients, news, OTP auth, roles and an admin panel. It is the reference to read —
  not a project to inherit.
- **Error reporting:** [error-reporting.md](error-reporting.md) — every error carries the route,
  the mounted features, the action and the user.
- **The AI toolkit:** [`toolkit/`](https://github.com/dartway/dartway/tree/master/toolkit) — the
  conventions, the lints and the skills that let an agent add a feature without tearing the project
  apart.
