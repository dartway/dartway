---
title: "The server is its features: lib/src/ by feature, DwAppServer(features:)"
affects:
  dartway_core_server: "0.21.0-dev.5"
  dartway_cli: "0.12.0"
---

## Who is affected

Every project. `DwAppServer` no longer takes `handlers:`, `channels:`, `jobs:` or `routes:`; it takes
`features:`. And `dartway check` now refuses a server `lib/src/` that is not laid out by feature
(`invalidTopLevelLayout`).

## The layout

`lib/src/` holds folders only:

- `core/` — sign-in hooks (`DwAuthConfig`), what the caller is and the access rules, channel
  addresses, upload rules, startup steps;
- `migrations/` — unchanged;
- one folder per feature — everything of that area: its row classes, handlers, rows → data objects,
  publications, jobs, rules — in files named after it, subfolders when it grows. It declares itself
  in `<feature>/<feature>_feature.dart`.

No file at the top of `src/`, and no layer folder there: `handlers/`, `rows/`, `entities/`, `domain/`,
`objects/`, `publications/`, `services/`, `models/`. Where an area was split across layers, gather it
into its feature's folder; what two features share goes to the one that owns it, or to `core/`.

Moving a row class changes nothing in the database: the table is named by `@DwSqlTable`, not by the
file. Rename the file's `part '….dw.dart'` to the new file name and run `dartway generate`.

## The declaration

Per feature, `<feature>_feature.dart`:

    final chatFeature = DwServerFeature(
      'chat',
      handlers: chatHandlers,
      channels: [
        DwChannelRule.keyed<int>(
          AppChannel.conversation,
          parseKey: int.parse,
          canSubscribe: (ctx, id) => ctx.isMemberOf(id),
        ),
      ],
      jobs: chatJobs,
    );

The channel rules that lived in one list (`AppChannels.rules`) move to the feature that owns each
channel kind; the channel addresses handlers publish to (`AppChannels.profileOf(…)`) stay in
`core/channels.dart`.

And the server lists the features:

    DwAppServer(
    - handlers: [...profileHandlers, ...chatHandlers],
    - channels: AppChannels.rules,
    - jobs: [...chatJobs],
    + features: [profileFeature, chatFeature],
      ...
    );

A feature's name is its folder's name: lower-case letters, digits and `_`. A test that builds a
`DwAppServer` of its own passes `features: [DwServerFeature('test', handlers: …)]`, or
`features: const []`.
