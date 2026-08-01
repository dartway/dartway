# How do I get a DartWay app running?

> Goal: a running fullstack Dart app in ten minutes, and your first feature — database to live
> screen — in twenty more. No endpoints are written anywhere in this guide.

## Prerequisites

- Dart SDK `>=3.11` and Flutter `>=3.41` (FVM works; the template carries a `.fvmrc`)
- Docker — the project brings up its own Postgres
- The Serverpod CLI, **pinned to the version the template depends on**:

  ```bash
  dart pub global activate serverpod_cli 3.4.11
  ```

  You need it as soon as you add your own models. Pin it: the CLI generates code for its own
  version, and a CLI newer than the `serverpod` in your pubspec produces a generated protocol that
  compiles and then misbehaves at runtime. Check with `dart pub global list`.

## 1. Create the project

```bash
dart pub global activate dartway_cli
dartway create my_app
```

You get three packages — `my_app_server`, `my_app_client` (generated), `my_app_flutter` — the agent
toolkit in `.claude/`, and a git repository with an initial commit.

What is inside is a **skeleton, not somebody's product**: passwordless phone auth, a `UserProfile`
with roles, navigation with zone guards, an admin panel (users + settings), a UI kit as source you
own, theming, localization, error reporting with app context. Zero domain models — your domain is
the part you write. What each folder is for: [project layout](project-layout.md).

## 2. Run it

The toolkit knows this stack, so the shortest path is to ask for it:

```bash
cd my_app
claude
```

…then say *"bring the project up"*. It starts Postgres, applies the migrations, seeds a dev user,
runs the server and the app, and tells you how to sign in. In VS Code the same thing is three launch
configurations: **Server**, then **Seed dev data**, then **Flutter (web)**.

By hand it is four commands, and the order matters:

```bash
cd my_app/my_app_server
dart pub get
docker compose up -d                                       # Postgres on 8090 (+ a test DB, MinIO)
dart bin/main.dart --apply-migrations --role maintenance    # apply the schema, then exit
dart bin/seed_dev.dart --mode development                   # one user per role
dart bin/main.dart                                          # run the server — this one stays up
```

`--role maintenance` is what makes the migration step *finish*. Without it `--apply-migrations`
applies the schema and then keeps serving, and the terminal never comes back for the seed.

In another terminal:

```bash
cd my_app/my_app_flutter
flutter pub get
flutter run
```

> **On an Android device or emulator**, `localhost` is the phone, not your machine. `lib/main.dart`
> carries a LAN address for that case — set it to your machine's IP. Web, desktop and the iOS
> simulator need no change.

The seed prints two phone numbers. Sign in as the plain user, `79990000003`; the admin is
`79990000001`. The one-time code is printed to the server console — in development nothing is sent
over SMS.

The home screen reads the app name from the database through the generic CRUD. Open the admin panel
as `79990000001`, change it, and watch the home screen update **without a reload**. That is the
whole path — Postgres → CRUD config → typed live list → widget — proving itself on the first screen.

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
dart bin/main.dart --apply-migrations --role maintenance
```

`serverpod generate` writes Dart into `lib/src/generated/` **and** into `my_app_client`. Neither is
edited by hand.

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
    // Who may write at all. The relation is declared nullable above, so the
    // generated `authorProfileId` is `int?` — an unowned note matches nobody.
    allowSave: (session, ctx) async =>
        session.isUser(ctx.currentModel.authorProfileId ?? -1),

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

Register it in `lib/src/dartway/dartway_core.dart`, in the `crudConfigurations` list the skeleton
already has:

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

That is the backend. `getOne`, `getList`, `save`, `delete`, filters, ordering and pagination are now
served for `Note` by the generic endpoint.

> **Secure by default:** a model with no config in this list is not reachable at all. You grant
> access; you never forget to take it away.

## 5. Show it

First register a default `Note` in `my_app_flutter/lib/core/default_models.dart`, next to the two
the skeleton already registers:

```dart
dw.repo.setupRepository(
  defaultModel: Note(id: dw.repo.mockModelId, text: 'Note text', createdAt: DateTime.now()),
);
```

That instance is not decoration: the loading skeleton is drawn from **your own widget** built
against it, which is why it resembles the content about to arrive. Skip it and the first build of
a `Note` list throws at runtime.

```dart
class NotesList extends ConsumerWidget {
  const NotesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(dw.repo.modelList<Note>()).dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (notes) => ListView(
            children: [for (final note in notes) NoteCard(note: note)],
          ),
        );
  }
}
```

No repository, no service, no provider, no API client. The list is typed, and it refreshes itself
for the person who writes to it — a save returns the updated rows to whoever saved them.

Writing goes through `dw.repo`, guarded by the action:

```dart
AppButton.primary(
  'Save',
  onTap: dw.action(
    (context) => dw.repo.saveModel(
      Note(authorProfileId: profile.id!, text: text, createdAt: DateTime.now()),
    ),
    onSuccessNotification: 'Saved',
  ),
)
```

A double tap does not create two notes; if `validateSave` rejects the write, its message reaches the
user as a notification. See [actions](../3-flutter/actions.md).

## 6. Make it live for everyone else

The list above updates for the author. For *other* users' screens to change, the config says so —
one line, on the server:

```dart
saveConfig: DwSaveConfig<Note>(
  // ...
  broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],
),
```

Nothing is added on the Flutter side: an app created by `dartway create` subscribes to that channel
at its root, and every model arriving on it is routed **by type** into any `dw.repo.modelList<T>()`
on screen. Open the app in two windows and watch.

Broadcasting is opt-in per model on purpose — a channel is an audience, and `accessFilter` has no
say over what travels on one. Public here is right because this config lets every signed-in user
read every note; a model scoped to its owner must narrow the channel instead. That decision, and
deleting alongside saving, is [realtime](../2-core/realtime.md).

## Where to go next

- **[What DartWay is](what-is-dartway.md)** — the idea the CRUD config comes from, and the honest
  limits.
- **[Project layout](project-layout.md)** — the three packages and every folder in them.
- **[Models](../2-core/models.md)** and **[CRUD configs](../2-core/crud-configs.md)** — steps 3 and
  4 above, in full.
- **[Access and roles](../2-core/access-and-roles.md)** — `accessFilter`, `allowSave`,
  `allowDelete`, and why there is no fourth place.
- **[The data layer](../3-flutter/data-layer.md)** — `dw.repo` in full: filters, single models,
  pagination, list skeletons.
- **[`example/`](https://github.com/dartway/dartway/tree/master/example)** — a complete application
  built exactly this way: a fitness club with a schedule, bookings with capacity rules, a staff-only
  chat invisible to clients, news, OTP auth, roles and an admin panel. It is the reference to read —
  not a project to inherit.
- **[Error reporting](../2-core/error-reporting.md)** — every error carries the route, the mounted
  features, the action and the user.
- **[The agent toolkit](../5-tooling/agent-toolkit.md)** — the conventions, the lints and the skills
  that let an agent add a feature without tearing the project apart.
