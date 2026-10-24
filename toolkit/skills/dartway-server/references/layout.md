## 1. Layout

```
bin/server.dart · bin/migrate.dart · bin/seed_dev.dart
lib/__SERVER_PKG__.dart     builds the DwAppServer: lists the features, the sign-in hooks, the upload rules
lib/generated/              written by generate
lib/src/core/               channels.dart (AppChannels) · environment.dart (AppEnvironment) · files.dart (AppFiles) · push.dart
lib/src/migrations/
lib/src/profile/            who the caller is (profile_access.dart), how others write a profile (profile_changes.dart)
lib/src/account/            the sign-in hooks and the first administrator; imported by nothing
lib/src/<feature>/          <feature>_feature.dart (its DwServerFeature) · _rows · _handlers · _objects
                            · _publications · _jobs · _access · _routes · _changes · logic/
```

The checks hold the shape (the law table in `CLAUDE.md`); the parts they cannot see:

- **A kind that outgrows its file splits by subject**, `<feature>_<part>_<kind>.dart`
  (`chat_messages_handlers.dart`); `logic/` is flat, free names, for what is none of the kinds.
- **Another feature's surface** is its `_rows` (read and join, never write), `_access` (its rules),
  `_objects` (its rows shown its way), `_publications`, `_changes` (its rows written its way — the
  only way another feature writes them). A number several features move (an admin counter) is one
  function in the owner's `_publications`, called by every command that moves it.
- **The profile imports no other feature** — every feature asks who the caller is. A cycle is broken by
  moving the shared rule to the `_access`, or the row class, to the feature that owns the concept — or
  what both need into a third feature both import.
- `core/` holds only what every feature needs and no feature's rule: an upload rule or a push audience
  lives in its feature's `_access.dart`, handed in by the library.
