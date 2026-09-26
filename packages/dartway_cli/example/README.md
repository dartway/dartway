# Example — from nothing to a running fullstack app

```bash
dart pub global activate dartway_cli
dartway create my_app
```

You get three packages — `my_app_shared`, `my_app_server`, `my_app_flutter` — and the agent
toolkit in `.claude/`.

```bash
cd my_app/my_app_server
docker compose up -d          # Postgres and RustFS
dart pub get
dart run bin/server.dart      # migrates itself, then serves — nothing else to run first

# in another terminal
cd ../my_app_flutter
flutter run
```

Register from the app with your own phone number; the one-time code is printed to the server
console. Your administrator identifier is set through `DW_ADMIN_IDENTIFIER` in
`deploy/secrets.yaml` (git-ignored) — the role is granted by an admin, so the first one is
declared per environment, not shipped in the skeleton.

What you get is a **skeleton, not somebody's product**: sign-in by a one-time code, a profile with
roles, navigation with zone guards, an admin panel, a UI kit as source you own — and no domain
models, because the domain is the part you write. The full path, command by command:
[quick start](https://dartway.dev/1-getting-started/quick-start).

## The other commands

```bash
dart run dartway_cli:dartway check     # the conventions, enforced: layout, generated code, migrations
dart run dartway_cli:dartway test      # server acceptance tests against a throwaway Postgres and storage
dart run dartway_cli:dartway stats     # code size per feature — what actually grew this week
dart run dartway_cli:dartway setup-ai  # install or update the AI toolkit (.claude/) in an existing project
```

## Options worth knowing

```bash
dartway create my_app --channel master        # the development trunk instead of `stable`
dartway create my_app --local-repo ../dartway # a local monorepo checkout, no clone
dartway create my_app --no-git                # skip the initial commit
```

`dartway check` is the same checker an AI agent runs before it claims to be done — see
[the CLI](https://dartway.dev/5-tooling/cli).
