---
name: dartway-feature-scaffold
description: >-
  Step-by-step playbook for building a new DartWay feature end-to-end (Flutter + Serverpod):
  navigation → UI entry point → state/logic via the data layer and Riverpod → backend CRUD configs
  → models/DB → tests. Feature structure (entry point + widgets + logic), isolation (import the
  entry point only), domain/app/ui_kit boundaries, the `DwFeatureSpec` feature spec in the feature's
  own file. Use when adding new functionality, a screen, a flow, or a model.
---

# DartWay — building a feature (end-to-end)

The playbook for adding a new feature. A DartWay feature is **small and self-contained**, and it runs through both the server and Flutter. Whenever you can, split every functional widget into its own feature, unless they share genuinely critical state.

See also: `__FLUTTER_PKG__/CLAUDE.md`, `__SERVER_PKG__/CLAUDE.md`, skills `dartway-crud-config`, `dartway-data-layer`, `dartway-models`, `dartway-navigation`, `dartway-ui-kit`, `dartway-clean-code`, `dartway-finish`.

> If the feature already exists — **read its public file first**: the `DwFeatureSpec` sitting right there *is* the current description of the behavior, and `knownIssues` tells you what has already been acknowledged as wrong in it. Server-side rules live in the doc comments above its `DwCrudConfig`. Change the behavior and you fix the spec in the same diff (Law 6).

## Feature structure (Flutter)

A feature lives in a **zone**, and the zones are the four folders at the top of `lib/`: `app/` (the app itself), `admin/` (the admin panel), `auth/` (signing in), `common/` (features more than one zone draws on). That list is closed — a fifth navigation zone in the router is a group inside `app/`, not a folder of its own — and so is the rest of the top level: `core/`, `shared/`, `ui_kit/`, `l10n/`, plus `main.dart` and `__FLUTTER_APP_FILE__`. `dartway check` reports anything else as `invalidTopLevelLayout`, a zone name used lower down included: `app/admin/` is not the admin panel, it is a group that has quietly left every check written for zones.

```
lib/app/<feature>/
  <feature>_page.dart        // entry point — the only public file
  widgets/
    <feature>_list.dart
    <feature>_item.dart
  logic/                     // optional
    <feature>_provider.dart
    <feature>_filter.dart
```

- **Entry point** — the only public file, and it is a widget: a Page, or a Widget that also carries its own way of being shown (see "Showing a feature" below). From outside the feature, only it is imported — and that is enforced at any nesting depth.
- **widgets/** — the feature's visual blocks.
- **logic/** — providers/enums/helpers belonging to this feature only.
- Cross-feature logic — an extension on a model, a formatter, a predicate — → `lib/shared/`, not inside the feature. (There is no `lib/domain/`: the rules of a DartWay app live in CRUD configs on the server, and what is left on this side is a helper.)
- Styles → `ui_kit.dart` only.
- Imports — relative for your own internals and for a sibling feature (never deeper than two `../`), `package:` for everything further away: `core/`, `shared/`, `ui_kit/`, another zone. See `dartway-clean-code` §1.2a; `deep_relative_import` flags the rest in the editor.

### Groups: when a feature stopped being one feature

A folder **without** root-level `.dart` files is a **group**. It only groups features: it encapsulates nothing, has no `widgets/`/`logic/` of its own, and **does not affect visibility** — the router is allowed to import `app/learning/lesson/lesson_page.dart`, because `lesson` is a feature and `learning` is a group.

The moment a feature gains a second public entity (a screen plus an embeddable block, a three-screen flow, a reusable card), it becomes a **group of several features**, not a feature with two root files:

```
app/community_events/                  // group
  community_events_block/              // block on the home screen
    community_events_block.dart
  community_events_page/               // the "All events" screen
    community_events_page.dart
    widgets/ community_events_filter_row.dart …
  community_event_card/                // both the block and the screen draw the card
    community_event_card.dart
    widgets/ community_event_detail_dialog.dart
    logic/   event_format_label_extension.dart
```

**Behaviour two features share is one more feature.** No new kind of entity is introduced: the card has exactly the same single public file as the screen.

**A widget with no story of its own is a building block, and blocks live in `lib/shared/`** — never in a `common/`/`shared/`/`widgets/` folder inside a zone. The line is not how many places use it but whether there is anything to tell:

| | Where | Described by |
|---|---|---|
| **Feature** — product behaviour you can name in a user's words (a screen, a dialog, a flow, a block on a screen) | a zone: `app/`, `admin/`, `auth/`, `common/` | `DwFeatureSpec` |
| **Building block** — a widget/helper features draw with: a form field, a badge row, a layout wrapper, an extension on a model | `lib/shared/` | a doc comment over the class |
| **Layer** — presentation, infrastructure, localisation | `ui_kit/`, `core/`, `l10n/` | — |

**Split small: that is the recommendation, not a tolerated evil.** Every feature brings a passport, so the finer the cut, the denser the description of the interface — one big feature is described in generalities, ten small ones each carry their own `behaviors` and `knownIssues`. A single consumer is not a sign of an internal; the sign of an internal is that there is nothing to tell (a slice of layout extracted so `build` stops growing).

**Not a feature:** app-wide registries and infrastructure (the feature catalog, analytics, push initializers) — that is `lib/core/`; a helper several features share — `lib/shared/`. The sign that the placement is wrong: the file sits in one feature's `logic/` and is imported from other features — then all of them are reaching into its internals.

The check is `dartway check`: it builds a "zone → group → feature" tree and grades every feature A–D.

## Where a feature's logic lives: three options

Choose **bottom-up** — start with the first and move up only when you hit a wall. A premature provider costs exactly as much as a premature abstraction.

### 1. Everything in the widget — the default

A couple of `watch` calls, a bit of layout, local state via hooks. Nothing needs to be extracted.

```dart
final events = ref.watch(dw.repo.modelList<CommunityEvent>());
final selectedTypeId = useState<int?>(null);
```

**When this is enough:** the data is read from `dw.repo` and drawn right away; the filter is a `.where` over local state; there is no derived value that would need explaining.

### 2. A provider plus a pure decision function — when state is derived

As soon as state is assembled **from several sources** or carries a rule ("access expired, but it was a trial — that's a different message"), the widget stops being the place for it. You introduce a provider — written by hand, a family keyed by parameters — and the decision moves into a factory on the state type next to it:

```dart
final courseLockStateProvider =
    Provider.family<CourseLockState, CourseLockKey>(
  (ref, key) => CourseLockState.resolve(              // ← what follows from the data
        userCourse: ref.watchUserCourseById(key.accessCourseId), // ← where it comes from
        hidePaidFeaturesInfo: ref.watchUserProfile.hidePaidFeaturesInfo,
        now: DateTime.now(),
      ),
);
```

**Why split the two halves:** the provider is responsible for *where* the data comes from, the factory for *what follows* from it. The factory is testable without a provider container, and time is passed into it as a parameter so that access expiry can be tested without moving the clock. The decision lives in a **factory constructor on the state type itself**, not in a free function (`dartway-clean-code` §1.3a). The provider is written by hand: code generation is off by default here, see the policy in `CLAUDE.md`.

**The anti-pattern that looks similar:** the widget manually collects three `watch` calls and feeds them into a function. Then the derived state is not cached and is recomputed on every build — that is a provider's job, not a widget's.

### 3. A Notifier — when the feature owns mutable state

A form draft, multi-select, a step-by-step flow, optimistic edits — things the feature **owns** and that change through its methods.

**Check before you introduce one:** does this duplicate what the server already knows? A write through `dw.repo` refreshes the lists by itself — "requests already sent" does not need to be accumulated in a `Set<int>`, the answer is already in the list of requests. Local state on top of server state is a second source of truth, and it can only drift apart from the first.

**State used by two features is a feature, and its public surface is a provider.**
Not "a state class plus a notifier plus a provider in one root file": the outside world only needs
the provider — both the state and the notifier's methods are reachable through it, the caller never
has to write the class names, they are inferred. So the root holds the provider, while the state
class and the notifier go into `logic/`, one file each:

```
admin_chats_filters/
  admin_chats_filters.dart              ← the provider only: the entire public surface
  logic/
    admin_chats_filters_model.dart      ← immutable state class + copyWith
    admin_chats_filters_state.dart      ← Notifier with the mutation methods
```

The inverse symptom — the state sits in one feature's `logic/` and a neighboring feature imports it:
that is a boundary violation, the checker will catch it, and it is cured by exactly this move.

**State only this feature uses may keep the notifier and the provider in one file — and then the
provider goes first.** What the file is imported for is the provider; the notifier is how it is
implemented. Written the other way round (the default that habit and the Riverpod docs produce), you
open the file, meet twenty-five lines of implementation, and scroll for the one line you came for.
Same principle as the feature's own folder — the public surface is one thing and it is in plain
sight — applied to a file. Either order it that way or split it as above; what is not an option is
the provider hidden underneath its own implementation.

## Order of work

### 1. Navigation
Decide the feature's entry point and its exit points. If a route is needed — add it (an enum route, see the `dartway-navigation` skill).

### 2. Interface (UI)
Create the entry point (a Page or a Widget), sketch the layout (buttons, lists, fields). Styles come from the UI Kit. Data can be mocked/hardcoded at this step.

The entry-point widget **declares what feature it is** — `implements DwFeature` with a `DwFeatureSpec` right in its own file (see "Feature spec" below). Without it, `dartway check` emits a `featureSpecMissing` warning.

**A folder in a zone whose entry point is not a widget is not a feature**, and `dartway check`
reports it as `notAFeature` (error). The case that produces it is always the same: a provider that
several features watch, given a folder of its own because it felt like it deserved one. It does not
belong in a zone — **state several features watch is wiring (`lib/core/`), and a helper with no
story of its own is a building block (`lib/shared/`)**. The tell is the passport: if you cannot
write `purpose` and `behaviors` for it without restating the type name, it was never a feature.

**Showing a feature that is not a route.** A sheet, a dialog or an overlay publishes itself as a
**static method on its own widget**, taking `BuildContext` first — `static Future<void> show(BuildContext context, …)`,
or `showCreate` / `showEdit` when there are several ways in:

```dart
class UserFormSheet extends StatelessWidget implements DwFeature {
  const UserFormSheet({super.key, this.userProfile});

  static Future<void> showCreate(BuildContext context) =>
      context.showAppBottomSheet(child: const UserFormSheet());

  final UserProfile? userProfile;
  ...
}
```

So the feature keeps **one** public entity, and it is the widget: the caller writes
`UserFormSheet.showCreate(context)` and can see from the name what opens. Do **not** publish the
feature as an `extension on BuildContext` (`context.showUserForm()`): that splits the feature into
two public files, hides the widget in `widgets/`, and names a screen without naming its feature —
see `dartway-clean-code` §1.3, which this convention is the answer to.

### 3. State & Logic
Decide what data the UI needs. Data access goes through `dw.repo` only: reads via the `dw.repo.model`/`maybeModel`/`modelList` providers under the native `ref` (`ref.watch(...)` reactively, `ref.read(....future)` one-off), writes via the `dw.repo.saveModel`/`deleteModel` methods. For complex scenarios or reuse inside the feature — a Riverpod provider. Local state — Riverpod + StatefulWidget + flutter_hooks. Describe every user action (create/edit/delete) before wiring it to the backend.

### 4. Backend (CRUD configs)
Every user action maps onto the CRUD layer — no arbitrary endpoints. Use `SaveConfig`/`DeleteConfig`/`GetModelConfig`/`GetListConfig`, wrap responses in `DwModelWrapper`. The configs hold permissions, validations, pre/post processing, side effects. Details — the `dartway-crud-config` skill.

### 5. Models & DB
Refine the models against the feature's real needs: fields and relations (1–1, 1–N, N–N). A field is nullable only if the value really can be absent in the domain, not for the UI's convenience. The schema reflects domain reality. After editing the YAML — `serverpod generate` + a migration.

### 6. Tests
Server: unit tests for every CRUD config (permissions, validations, pre/post, sideEffects), tests for Event models. Flutter: a widget test for the entry point, provider tests for the logic, integration tests for navigation and the key actions. The threshold depends on complexity (see `dartway-clean-code`, Part 3).

### 7. Finishing (Law 6)
Run the `dartway-finish` skill: it audits the diff against the contract, reconciles `DwFeatureSpec` with the new behavior, and checks test coverage. No separate doc is created for the feature — the description already lives in its file. The skill shows suggestions and applies only what you confirm.

## Feature spec (`DwFeatureSpec`)

A feature describes itself **in its own file**, next to the code — and that is its only description. No registry, no separate doc: a description living away from the code drifts from it on the very first edit, and it does so silently — the compiler does not check it, the checker does not see it, and the agent reads it and believes it. That same description is read by error reports, DartWay Studio, and the agent.

```dart
class BookingListPage extends ConsumerWidget implements DwFeature {
  const BookingListPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'bookings/list',
    title: 'My bookings',
    purpose: 'The client sees what they are booked for and can cancel a booking.',
    behaviors: [
      'Bookings are sorted by date, the nearest one on top.',
      'Cancelling removes the booking from the list without a reload.',
      'A past booking cannot be cancelled — there is no button.',
    ],
    requirements: [
      'A client sees only their own bookings — decided by accessFilter on the backend, not by the widget.',
    ],
    implementationNotes: [
      'The list is not cached: a booking changes more often than the screen is opened.',
    ],
    knownIssues: [
      'Sorting by date is commented out in the list even though the field is still in the form —'
          ' the order is currently random.',
    ],
  );
```

Rules per field:

- **`id`** — `<feature-folder>/<meaningful-name>`. This is a **contract**: Studio, feedback, and tickets refer to the feature by it. The folder moved — the id stays. Need a different name — introduce a new id and retire the old one, but **do not rename it in place**.
- **`title`** — what the feature is called out loud.
- **`purpose`** — why the user needs it. **Optional and often unnecessary:** a card or a list row has no purpose of its own, it serves the screen; repeating the screen's purpose on every one of its parts is noise.
- **`behaviors`** — what the feature observably does, one verifiable statement per item. **The criterion that keeps this field alive: every item can be verified by looking at the running app.** The moment "works well with long titles" shows up, the field has turned back into an essay.
- **`requirements`** — what the feature is obliged to honor, imposed **from the outside** (authorized users only, the price is not shown before confirmation, works offline). If it is phrased as an observable action, it belongs in `behaviors`.
- **`implementationNotes`** — what the code cannot say about itself: why it is done this way, a trap that is not visible from the outside, a decision that would otherwise be re-opened. Written for the team, not for the client: Studio shows them on the technical side. **The test: would this still be worth reading after the feature is rewritten?** A reason survives ("the list is not cached — it changes more often than it is read"); a trap survives ("the server sends the date in UTC, the screen shows it local"). A map of the code does not: "the list comes from `dw.repo.modelList` and is drawn by a `ListView`" is what the code already says, and it starts lying the moment someone moves the widget.
- **`knownIssues`** — what is **wrong** in the feature and worth picking up: a setting nobody reads; a screen still sitting on mocks; sorting commented out while the field is still live in the form.

**The line between `implementationNotes` and `knownIssues` is what the reader is supposed to do about it.** A note says "this is intentional, don't touch it", a finding says "this is wrong, fix it". The agent needs that distinction **before** it changes anything: otherwise it either "fixes" a deliberate decision or carefully preserves a bug. One question settles it: **if this gets fixed, does the entry disappear?** It disappears — `knownIssues`. It stays as an explanation — `implementationNotes`.

Write one sentence per item: what is wrong and what it costs. This is a pointer for whoever picks the feature up, not a tracker — a ticket is created from that line, and the line itself is deleted together with the fix. Studio shows a counter for such features and can filter by it.

**A finding is only visible while reading the code — so it must be recorded there and then.** You noticed along the way that a field is saved and read by nobody — that is a line in that feature's `knownIssues`, not a "should look into it later". This is the only way such things survive long enough to be dealt with.

**Write the spec from what the code does, not from what was intended.** While you phrase verifiable statements you find things nobody ever claimed — that is how it surfaced that the events block on the home screen does not sort them by date while the screen does.

The spec lives on a widget, which is another reason the entry point is one. A feature published as an extension or a bare function (`context.showInviteDialog()`) has nothing to attach the spec to — the checker cannot ask it for one, and the feature ends up with no description at all. If you meet one, that is what to fix: move the presentation into a static method on the widget (see "Showing a feature that is not a route") and the spec has a home.

## Entry point example

```dart
// todo_list_page.dart
class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(todoSearchStringProvider);
    final todos = ref.watch(dw.repo.modelList<Todo>());

    return Scaffold(
      body: todos.dwBuildListAsync(
        loadingItemsCount: 5,
        // local filtering — a plain .where in the widget; there is deliberately
        // no "framework" way to do it (see dartway-data-layer §3)
        childBuilder: (list) => ListView(
          children: [
            for (final todo in list.where(
              (t) => search == null || t.title.contains(search),
            ))
              TodoItem(todo: todo),
          ],
        ),
      ),
      // `dw.action(...)` returns a DwUiAction, not a VoidCallback: you cannot hand
      // it straight to onPressed. DwActionBuilder unwraps it under a tap — it also
      // suppresses repeat taps and exposes busy.
      floatingActionButton: DwActionBuilder(
        action: dw.action((_) async {
          await dw.repo.saveModel(
            Todo(title: 'New task', isCompleted: false, createdAt: DateTime.now()),
          );
        }),
        builder: (context, onPressed, busy) => FloatingActionButton(
          onPressed: onPressed, // null while the action is running
          child: busy
              ? const CircularProgressIndicator()
              : const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

The essentials: `AsyncValue` lists — through `dwBuildListAsync` (with `loadingItemsCount`); local search/filter — a `.where` in the widget (plus a provider for the search string); actions from the UI — inside `dw.action` (the callback receives `context`; use `(_)` if you don't need it — see `dartway-data-layer` §4).
