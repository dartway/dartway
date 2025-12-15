# dartway_serverpod_core

The **core engine of DartWay backend** — this package transforms [Serverpod](https://serverpod.dev) into a flexible, production-ready foundation with unified repositories, configurable CRUD, and seamless front–back integration.

Unlike low-level abstractions, `dartway_serverpod_core` defines the entire data and interaction model that connects the Flutter client and Serverpod backend into one coherent system.

---

## 🚀 Features

### 🧩 Unified Repository Layer

A shared contract between the client and the server. Every data model has a unified repository that automatically syncs operations across frontend and backend.
No more manual service wrappers or boilerplate — repositories provide:

* Type-safe CRUD methods (create, update, delete, find) for both client and server.
* Built-in pagination, filtering, and sorting.
* Seamless real-time updates via WebSocket when data changes on the backend.

**Why it’s great:** you work with the same API on Flutter and Serverpod — no duplicated logic, no desyncs, no custom endpoints.

---

### ⚙️ Configurable CRUD Backend

Define your data once — and DartWay generates endpoints, validation, and access control automatically.
Each entity can declare its CRUD behavior in a single configuration file, including permissions, filters, and relations.

**Why it’s great:**

* 10× faster feature delivery — minimal backend boilerplate.
* Unified conventions — every module behaves the same way.
* Easy debugging and scaling — consistent logs, queries, and schema updates.

---

### 🧠 Smart Backend Utilities

* **Service lifecycle hooks** — run custom logic before/after operations.
* **Structured logging** with request tracing and user context.
* **Access control** utilities for per-user and per-role data visibility.
* **Background tasks** and async helpers for scheduled jobs.
* **Error handling** with uniform JSON responses and stack traces.

---

## ⚡ Quick Start

Visit [dartway.dev](https://dartway.dev) for documentation, setup, and working examples.

You can also explore the [DartWay Project Template](https://github.com/dartway-dev/dartway_template) to see how `dartway_serverpod_core` integrates into a full Flutter + Serverpod stack.

---

## 🧩 Part of the DartWay ecosystem

[DartWay](https://github.com/dartway-dev/dartway) is a **full-stack Dart framework** that accelerates startup development 3–4× faster with Flutter + Serverpod.

This package is one of the key pillars connecting the frontend and backend layers.

---

## 🤝 Contributing

Contributions are welcome!
Please see [CONTRIBUTING.md](../CONTRIBUTING.md).
All commits must include a `Signed-off-by` line (DCO).

---

## ⚖️ License

Licensed under the [Apache License 2.0](../LICENSE).
