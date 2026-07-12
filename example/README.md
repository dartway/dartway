# DartWay Project Template

Starter template for creating new projects with **DartWay** (Flutter + Serverpod).  
This repository provides the base structure for:
- `dartway_example_flutter` — Flutter application
- `dartway_example_server` — Serverpod backend
- `dartway_example_client` — generated API client

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
2. Run the rename script to replace `dartway_example` with your project’s name  
3. Install dependencies and generate code  
4. Start coding your app 🚀

See [DartWay Quickstart Guide](https://dartway.dev/docs/quick-start) for full details.

## Tests

The server carries the integration suite for DartWay's auth limits — attempt
caps, code expiry, request rate limiting and single-use access tokens. They run
against a real database, because that is the only place the guarantees hold:
the limits are enforced with database locks, and a race cannot be observed in a
rolled-back transaction.

```bash
cd dartway_example_server
docker compose up -d          # dev database on 8090, test database on 9090
dart test --concurrency=1
```

`--concurrency=1` keeps test files from sharing the database. The suite commits
real transactions (see `RollbackDatabase.disabled`) and wipes the auth tables
between cases.
