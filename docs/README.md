# DartWay Documentation Content

This folder is the **single source of truth for dartway.dev documentation content**. It lives in the framework monorepo so that docs evolve in the same PR as the code they describe (see the sync law in the root `CLAUDE.md`).

The Docusaurus site (separate `dartway.dev` repository) pulls this folder at build time. Setting up that build integration is a pending task tracked in `project/NEXT.md` — until then, the site is updated manually.

Conventions:
- Content language: English.
- One page per file, kebab-case names (`quick-start.md`).
- Code samples must match the current `example/` project — if they drift, fix them in the same PR that changed the API.
