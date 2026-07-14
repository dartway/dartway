# DartWay Project Template

Starter template for creating new projects with **DartWay** (Flutter + Serverpod).  
This repository provides the base structure for:
- `dartway_starter_flutter` — Flutter application
- `dartway_starter_server` — Serverpod backend
- `dartway_starter_client` — generated API client

## 🚀 Quickstart

Follow the step-by-step guide to create a new project:  
👉 [DartWay Quickstart Guide](https://dartway.dev/docs/quick-start)

## Features

- Pre-configured **DartWay rules** for Cursor/AI coding
- Ready-to-use Flutter + Serverpod integration
- Structured project layout (app, server, client)
- Scripts for renaming and setting up your own project

## How to use

1. Clone this repo as your new project folder  
2. Run the rename script to replace `dartway_starter` with your project’s name  
3. Install dependencies and generate code  
4. Start coding your app 🚀

See [DartWay Quickstart Guide](https://dartway.dev/docs/quick-start) for full details.

## Tests

The server carries DartWay's integration suites: the auth limits — attempt caps,
code expiry, request rate limiting, single-use access tokens — and password
hashing, including the migration of a legacy hash on the user's next sign-in.
They run against a real database, because that is the only place the guarantees
hold: the limits are enforced with database locks, a race cannot be observed in
a rolled-back transaction, and neither can a hash that must actually be written.

```bash
cd dartway_starter_server
docker compose up -d          # dev database on 8090, test database on 9090
dart test
```

The suites commit real transactions (`RollbackDatabase.disabled`) and wipe the
auth tables around themselves, which makes them stateful neighbours rather than
isolated units: run in parallel they wipe each other's rows mid-test. Files
therefore run one at a time — pinned in `dart_test.yaml`, not left to whoever
remembers a flag.
