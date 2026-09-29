---
title: "One way to show a read, a feed, a spinner, a dialog and a route: DwReadBuilder, DwPagedListView, and dartway check fails the rest"
affects:
  dartway_core_flutter: "0.21.0-dev.9"
  dartway_cli: "0.13.0"
---

## Who is affected

Every project with a Flutter package:

- `DwFlutterCore` now refuses a `DwFlutterConfig` without `readLoadingBuilder` and
  `readFailedBuilder` — an `ArgumentError` at start;
- `dwBuildAsync` and `dwBuildListAsync` are gone, and with them every project's own
  `.section(...)` extension built on them;
- `DwWindowListView` has no `loadingBuilder`/`errorBuilder` any more, and `emptyBuilder` is required;
- `dart run dartway_cli:dartway check` fails on four new errors: `forbiddenRequestRead` (a read's
  `AsyncValue` taken apart in a widget), `forbiddenProgressIndicator` (a spinner outside `ui_kit/`),
  `forbiddenNavigationCall` (a raw dialog, sheet, push or page route outside `ui_kit/` and
  `core/router/`, or a pop not spelled `Navigator.of(context).pop(…)`) and `sentinelId` (`0`/`-1`
  as an id).

## What to change

**1. Hand the kit's views to the core, once** (`lib/core/dw_core.dart`). The kit gets one spinner if it
has none — copy `template/dartway_starter_flutter/lib/ui_kit/1_essentials/app_progress_indicator.dart`
(and add its `part` line to `ui_kit.dart`) — and its load-failed widget becomes the failed view:

    config: DwFlutterConfig(
      …
    + readLoadingBuilder: (context) =>
    +     const Center(child: AppProgressIndicator()),
    + readFailedBuilder: (context, error, retry) => LoadFailedMessage(
    +   message: switch (error) {
    +     DwRefusalException(:final refusal) => appL10n.refusalText(refusal),
    +     _ => appL10n.loadFailed,
    +   },
    +   retryLabel: appL10n.retry,
    +   onRetry: dw.action((_) => retry()),
    + ),
    ),

**2. The project's `.section(...)` extension becomes `DwReadBuilder`, and its file goes** (the
skeleton's was `lib/core/async_section.dart`; some projects keep theirs beside
`LoadFailedMessage` in `lib/shared/`). Per call — the read moves in, `loadingValue` is `placeholder`,
`onRetry` and `loadingWidget` go (retry and the loading view are the core's now), the builder takes a
context:

    - ref
    -     .watch(dw.request(request))
    -     .section(
    -       loadingValue: placeholder,
    -       onRetry: () => ref.read(dw.request(request).notifier).refetch(),
    -       builder: (value) => View(value),
    -     )
    + DwReadBuilder(
    +   dw.request(request),
    +   placeholder: placeholder,
    +   builder: (context, value) => View(value),
    + )

A call with `loadingWidget:` drops it and has no `placeholder` — the app's loading view shows. A bare
`dwBuildAsync(...)`/`dwBuildListAsync(...)` over a read is the same edit (`loadingValue`/`loadingItem`
→ `placeholder`, `childBuilder` → `builder`, `errorWidget`/`errorBuilder` gone). A widget left with no
`ref` becomes a `StatelessWidget`/`HookWidget`.

**3. A refusal screen checked before the builder becomes an `onRefused` branch:**

    - final card = ref.watch(request);
    - if (card case AsyncError(error: DwRefusalException(:final refusal))
    -     when refusal.isCode(DwCoreRefusal.notFound)) {
    -   return Unavailable();
    - }
    - return card.section(…, builder: (card) => CardView(card));
    + return DwReadBuilder(
    +   request,
    +   onRefused: {DwCoreRefusal.notFound: (context, _) => Unavailable()},
    +   builder: (context, card) => CardView(card),
    + );

A project code is keyed the same way (`<Package>Refusal.lessonClosed: …`). A page title that read
`card.value?.name ?? fallback` shows the fallback, and the name moves into the builder's view.

**4. Every other `.value`, `.when(`, `.hasError`, `switch` over a read in a widget** (the check lists
each):

- two reads combined by hand → nest the builders, the inner one in the outer one's `builder`;
- a number the layout needs whatever the read answers (a badge, whether a bar takes room) → a
  provider in the feature's `logic/` that watches the read and answers the number, watched by the
  widget (`example/dartway_example_flutter/lib/app/chat/logic/chat_counts.dart`);
- a form whose options come from a read → the form is the builder's child, a widget of its own
  taking the value (`template/…/admin/analytics/widgets/analytics_widget_editor.dart`).

**5. A feed's hand-written load-more trigger becomes `DwPagedListView`** — a scroll listener with a
pixel threshold, a `NotificationListener` on `extentAfter`, a "more" button:

    - ref.watch(dw.pages(request)) … ListView(controller: scroll, …)
    - scroll.addListener(() { if (… < 300) ref.read(dw.pages(request).notifier).loadMore(); });
    + DwPagedListView<Post>(
    +   request: request,
    +   placeholder: placeholderPost,
    +   header: const FeedHeader(),        // what scrolled above the rows
    +   emptyBuilder: (context) => …,
    +   itemBuilder: (context, post) => PostCard(post),
    + )

It asks for the next page when the slot after the last row comes into the cache extent, and shows a
retry there after a failed page.

**6. `DwWindowListView`**: delete `loadingBuilder:` and `errorBuilder:` (the core's views show; a
refusal with a screen of its own is `onRefused:`), and pass `emptyBuilder:` if you did not.

**7. Spinners, dialogs, pops** (`forbiddenProgressIndicator`, `forbiddenNavigationCall`):

- `CircularProgressIndicator(...)` outside `ui_kit/` → `AppProgressIndicator(value:, size:)`;
- `showDialog(context: context, builder: (_) => Dialog(child: x))` → `context.showAppDialog(child: x)`
  (copy `ui_kit/2_frequent/show_app_dialog_extension.dart` from the skeleton);
  `showModalBottomSheet` → `context.showAppBottomSheet(child: …)`;
- an `AlertDialog` asking yes/no before an action → `dw.action(…, confirmation:
  DwUiConfirmation(message, title:, confirmLabel:, cancelLabel:, isDestructive: true))`;
- `Navigator.push(MaterialPageRoute(builder: (_) => Page()))` → a route of the zone
  (`.simple`/`.parameterized` descriptor) and `GoRouter.of(context).goNamed(Zone.page.name, …)`;
- `Navigator.pop(context)`, `GoRouter.of(context).pop()`, `context.pop()` →
  `Navigator.of(context).pop()`.

**8. What a screen opens on is its address** — not checked, and the one to look for by hand: a
provider set just before `goNamed` and cleared by the page once read ("focus this item", "scroll to
this message") becomes a path or query parameter the page reads with `fromPath`/`fromQueryOrNull`.

**9. "New" is a route of its own** (`sentinelId`): an edit route opened with `courseId.set(0)` and an
`if (id == 0)` in the page becomes a `.simple` create route beside the `.parameterized` edit route;
"none" is `null`. A command sent with id `0` for "create" is the same fix on the command side (not
checked).

## How to check

    dart analyze
    dart run dartway_cli:dartway check      # no forbiddenRequestRead, forbiddenProgressIndicator,
                                            # forbiddenNavigationCall, sentinelId
    flutter test
