# Quick Start

> Goal: a working fullstack Dart app with a live-synced list in ~15 minutes.
> Status: skeleton — being finalized alongside the pub.dev release (tracked in `project/NEXT.md`).

## What you'll build

A minimal app on the DartWay stack (Flutter + Serverpod + DartWay core):

- a data model defined once, on the server;
- CRUD with access control and validation — **without writing endpoints**;
- a Flutter screen showing a live, real-time synced list via `ref.watchModelList<T>()`.

The reference implementation is the [`example/`](../example/) project in this repository (server + generated client + Flutter app).

## Prerequisites

- Dart SDK ^3.11 / Flutter ^3.41 (FVM recommended, see `.fvmrc`)
- Docker (Postgres + Redis for Serverpod)
- Serverpod CLI

## 1. Get the project

<!-- TODO(release): replace with `dartway create` / template instructions once packages are on pub.dev -->

Clone the monorepo and run the example:

```bash
git clone https://github.com/dartway/dartway.git
cd dartway/example/dartway_example_server
docker compose up -d
dart bin/main.dart --apply-migrations
```

Then run the Flutter app:

```bash
cd ../dartway_example_flutter
flutter run
```

## 2. Define a model

Models are declared in `.spy.yaml` on the server (see `example/dartway_example_server/lib/src/models/`). After editing, run `serverpod generate` and create a migration.

## 3. Configure CRUD — instead of writing endpoints

One declarative config per model (see `example/dartway_example_server/lib/src/crud/feed_post_crud_config.dart`):

```dart
final feedPostCrudConfig = DwCrudConfig<FeedPost>(
  table: FeedPost.t,
  getListConfig: DwGetModelListConfig<FeedPost>(
    accessFilter: (session) async => null,
    include: FeedPost.include(authorProfile: UserProfile.include()),
  ),
  saveConfig: DwSaveConfig<FeedPost>(
    allowSave: (session, ctx) async =>
        session.isUser(ctx.currentModel.authorProfileId),
    validateSave: (session, ctx) async =>
        ctx.currentModel.title.trim().isEmpty ? 'Title is required' : null,
  ),
);
```

Register it in `DwCore.init(...)` — done. `getAll`, `getOne`, `save`, `delete`, counts, filters, pagination and real-time updates are served by the generic DartWay endpoint.

## 4. Show live data in Flutter

```dart
class FeedPostList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<FeedPost>().dwBuildListAsync(
      loadingItemsCount: 5,
      childBuilder: (posts) => ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, i) => FeedPostCard(post: posts[i]),
      ),
    );
  }
}
```

No repositories, services, providers or API code — the list is typed, paginated and updates in real time when anyone saves a `FeedPost`.

## Next steps

- Explore the `example/` app: auth (OTP), profiles, file uploads, real-time channels.
- Read about the security model: access filters and save hooks. <!-- TODO(docs): security-model.md -->
- Project conventions and AI-agent toolkit: [`toolkit/`](../toolkit/).
