# Changelog

## 0.1.0

First public release — the DartWay command-line tool.

**`dartway create`** — a new project from the DartWay skeleton: server, generated client and Flutter
app, plus the AI toolkit in `.claude/`. What you get is a skeleton, not somebody's product: phone
auth with one-time codes, a `UserProfile` with roles, navigation with zone guards, an admin panel,
a UI kit as source you own — and zero domain models, because the domain is the part you write.

**`dartway check`** — the conventions, enforced: errors fail the run, warnings and infos are
advisory. File length is a soft signal (over 120 lines an info, over 200 a warning) rather than a
hard rule, because a limit you cannot honestly meet is a limit people learn to ignore.

**`dartway stats`** — code size per feature: what actually grew this week.

**`dartway setup-ai`** — installs or updates the AI toolkit in an existing project, overwriting only
the files it manages.
