# Example — from nothing to a running fullstack app

```bash
dart pub global activate dartway_cli
dartway create my_app
```

Eighteen seconds later you have three packages — `my_app_server`, `my_app_client` (generated),
`my_app_flutter` — and the AI toolkit in `.claude/`.

```bash
cd my_app/my_app_server
docker compose up -d                       # Postgres
dart bin/main.dart --apply-migrations      # schema
dart bin/seed_dev.dart --mode development  # one user per role

# in another terminal
cd ../my_app_flutter
flutter run
```

Sign in with `79990000003`; the one-time code is printed to the server console.

What you get is a **skeleton, not somebody's product**: phone auth, a `UserProfile` with roles,
navigation with zone guards, an admin panel, a UI kit as source you own — and no domain models,
because the domain is the part you write.

## The other commands

```bash
dartway check     # the conventions, enforced: file length, styles outside the kit, feature layout
dartway stats     # code size per feature — what actually grew this week
dartway setup-ai  # install or update the AI toolkit (.claude/) in an existing project
```

## Options worth knowing

```bash
dartway create my_app --channel master        # the development trunk instead of `stable`
dartway create my_app --local-repo ../dartway # a local monorepo checkout, no clone
dartway create my_app --no-git                # skip the initial commit
```

`dartway check` is the same checker the course uses to validate homework, and the same one an AI
agent runs before it claims to be done.
