# DartWay Dev Guidelines

This repository contains the **official development guidelines for DartWay projects**.

It serves two purposes:

1. **For developers** — guidelines are published on the DartWay documentation site as a knowledge base: how to structure projects, how to work with Flutter and Serverpod, what conventions and rules to follow.
2. **For AI-assisted development (Cursor)** — the same guidelines are used as `rules` inside the [Cursor IDE](https://cursor.sh). This ensures that when developers work with AI coding assistants, the AI follows the same standards and project conventions.

By keeping these rules in a single repository, we guarantee **full synchronization** between human-readable documentation and machine-readable rules.

---

## 📂 Structure
dev-guidelines/
- `foundations` — general architecture and development principles for DartWay projects.
- `flutter` — rules for Flutter codebases (UI, features, state, design tokens).
- `server` — rules for Serverpod backend (endpoints, DB, services).
---

## 🚀 Usage

### 1. As documentation (Docusaurus)
This repo is included into the DartWay website as a subtree:

```bash
git subtree add --prefix website/docs/dev-guidelines \
  https://github.com/dartway/dartway_guidelines main --squash
```


2. As Cursor rules

The same repo is used inside projects to provide AI coding guidance in Cursor IDE
.

Rules are added via subtree directly into .cursor/rules/ (and scoped to project parts):

```bash
# Foundations (global rules)
git subtree add --prefix .cursor/rules/dev-guidelines/foundations \
  https://github.com/dartway/dartway_guidelines main --squash

# Frontend (Flutter) rules
git subtree add --prefix frontend/.cursor/rules/dev-guidelines/frontend \
  https://github.com/dartway/dartway_guidelines main --squash

# Backend (Serverpod) rules
git subtree add --prefix backend/server/.cursor/rules/dev-guidelines/backend \
  https://github.com/dartway/dartway_guidelines main --squash

```

Update to the latest version:
```bash
git subtree pull --prefix .cursor/rules/dev-guidelines/foundations \
  https://github.com/dartway/dartway_guidelines main --squash
```

This ensures that when developers use AI to generate code, the AI follows the same standards that are written in documentation.

💡 Why this matters
Single source of truth → no duplication between docs and Cursor.
Consistency → both humans and AI follow the same standards.
Scalability → easy to update rules once and roll them out across projects.
Transparency → new developers can learn the rules from the website, while AI already enforces them inside IDE.

📜 License
Apache 2.0 — see LICENSE
