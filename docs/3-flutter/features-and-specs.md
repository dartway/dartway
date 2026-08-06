# What is a feature, and how does it describe itself?

A DartWay app is not a pile of screens. It is a tree of **features**: small, self-contained units
with exactly one public file and a description of themselves written next to their code.

Two ideas do the work here. The first is structural — a folder's shape decides what it is, nothing
is declared. The second is semantic — a feature says out loud what it does and what is wrong with
it, in the same file, so the description cannot drift away from the code.

## The shape of a feature

```
lib/app/bookings/
  my_bookings_page.dart        ← the entry point: the only public file
  widgets/
    booking_card.dart
    review_bottom_sheet.dart
  logic/                       ← optional
    booking_filter.dart
```

- **A feature is a folder with a root `.dart` file.** That single file is its entire public surface.
- **`widgets/` and `logic/` are internals.** Nothing outside the feature may import them, at any
  nesting depth.
- **A group is a folder with no root `.dart` file at all.** It only groups features: it encapsulates
  nothing, owns no `widgets/` or `logic/`, and does not affect visibility. A router importing
  `app/learning/lesson/lesson_page.dart` is fine, because `learning` is a group and `lesson` is a
  feature.

Nothing is configured. `dartway check` builds this tree from the file system and grades every
feature, so the model is the folder layout itself rather than a manifest that can disagree with it.

Two rules follow, and the checker enforces both:

- **more than one root file is an error** (`invalidFeatureStructure`). A second public entity means
  the feature became a *group of features* — a screen plus an embeddable block, a card two screens
  both draw. Behaviour two features share is one more feature — but a widget with no story of its
  own is not a feature at all: that is a building block, it belongs in `lib/shared/`, and the
  checker asks it for no spec;
- **importing another feature's `widgets/` or `logic/` is an error** (`forbiddenFeatureImport`). If
  a file in one feature's `logic/` is wanted by three others, it was never that feature's internal.

Not everything is a feature. App-wide infrastructure (routers, analytics, push init, the model
registry) lives in `lib/core/`; a widget or helper features draw with — extensions on models
included — lives in `lib/shared/`. And a feature always sits in one of the four zones, never
outside them: see [the project layout](../1-getting-started/project-layout.md).

## The spec lives in the code

The feature's public widget declares what it is:

```dart
class MyBookingsPage extends ConsumerWidget implements DwFeature {
  const MyBookingsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'bookings/my-bookings',
    title: 'My bookings',
    purpose:
        'A member checks what they have signed up for, and which visits they '
        'have already reviewed.',
    behaviors: [
      'Bookings are sorted by session start, the latest first.',
      'A booking that already has a review is marked as reviewed.',
      'With no bookings the screen says so instead of showing an empty list.',
    ],
    requirements: [
      'A member sees only their own bookings; staff sees all of them. The '
          'decision is the server access filter, not this screen.',
    ],
    implementationNotes: [
      'Two watches, joined locally: the bookings themselves and the reviews, '
          'intersected by bookingId.',
    ],
  );
```

`DwFeature` is an interface with a single getter and no behavior — the widget declares a
descriptor, nothing else changes. The point of putting it *here* rather than in a registry or a
markdown file: a description that lives away from the code drifts on the first edit, silently. The
compiler does not check it, the checker cannot see it, and the reader — increasingly an agent —
believes it.

A feature whose entry point is a widget but declares no spec gets a `featureSpecMissing` warning
from `dartway check`. A feature whose entry point is an extension or a function
(`context.showInviteDialog()`) has nothing to hang a spec on, and the checker leaves it alone.

## The fields

| Field | What goes in it |
|---|---|
| `id` | stable identifier, `<feature>/<name>` — a **contract** |
| `title` | what the team calls it out loud |
| `purpose` | why the user needs it — optional |
| `behaviors` | verifiable statements about what it observably does |
| `requirements` | what it must honour, imposed from outside |
| `implementationNotes` | decisions a reader would otherwise re-open |
| `knownIssues` | what is wrong here and worth taking into work |

**`id` is a contract.** Studio passports, feedback and tracker items refer to the feature by it, and
it deduplicates a feature declared by several widget instances. Move the folder, rename the class —
the id stays. Needing a different name means introducing a new id and retiring the old one, never
rewriting one in place.

**`purpose` is optional on purpose.** A card or a list row has no purpose of its own; it serves the
screen it sits on. Repeating the screen's purpose on each of its parts is noise.

**`behaviors` has one rule that keeps the field alive: every entry must be verifiable by looking at
the running app.** "Tapping a card opens the details dialog" — yes. "With no subtitle the second
line is not rendered" — yes. The moment "works nicely with long titles" appears, the field has
turned back into prose and stops being worth reading.

**`requirements` is what is imposed from outside** — signed-in users only, no price before
confirmation, works offline. If you can phrase it as an observable action, it is a behavior.

A side effect worth knowing about: writing behaviors as verifiable statements is how you discover
things nobody claimed. Phrasing them for the events block on a home screen is what surfaced that the
block does not sort by date while the full screen does.

## `implementationNotes` vs `knownIssues`

These two look alike — both are notes about the implementation — and confusing them is the single
most expensive mistake in a spec, because an agent editing the feature reads them **before** it
touches anything.

The line is **what the reader is supposed to do about the entry**:

- a **note** says *this is deliberate, leave it alone*;
- an **issue** says *this is not right, fix it*.

Get it backwards and you get the two failure modes exactly: an agent that carefully "fixes" a
deliberate decision, or one that carefully preserves a bug because it read like an explanation.

One question settles every case: **if someone fixed this, would the entry disappear?**

- It disappears → `knownIssues`. *"Sorting by date is commented out in the list while the field is
  still in the form — the order is currently random."* Fix the sort, delete the line.
- It survives as an explanation → `implementationNotes`. *"The row shows the preview image and the
  list the full one, because the row is rebuilt on scroll."* Nothing to fix; the reason stays true.

Keep an issue to one sentence: what is wrong and what it costs. This is a pointer for whoever picks
the feature up, not a tracker — the tracker item is written *from* the line, and the line is deleted
together with the fix.

**A finding is only visible while you are reading the code.** Noticing along the way that a setting
is written and read by nobody is a line in `knownIssues` right then, not a "should look into that".
That is the only way such things survive long enough to be dealt with.

## Where the spec goes

`DwFeatureSpec` is not documentation for humans only. It is read at runtime.

`DwFeature.scanMounted()` walks the element tree from the app root and returns the specs of every
`DwFeature` widget currently **on screen**, deduplicated by id. It scans from the root rather than
from a `BuildContext` because the interesting question is "what is on this screen", not "what is
above this widget".

Mounted is not the same as visible, and the difference is not an edge case — an inactive bottom-nav
tab kept alive in an `IndexedStack`, or a route sitting under a pushed opaque one, stays in the
element tree. Counting those would report roughly the whole app on every screen. So the walk stops
at the three widgets Flutter itself uses to park a subtree out of sight: an offstage `Offstage`, an
invisible `Visibility` (what `IndexedStack` wraps unselected children in) and a disabled
`TickerMode` (what `Overlay` wraps the routes below an opaque one in).

Because the scan reflects what is mounted *now*, call it from a post-frame callback once the route
has settled; a widget mounted asynchronously afterwards is picked up by the next scan.

Two consumers use it today:

- **Error reports.** Every `DwErrorReport` carries `context.featureIds`. An alert from a minified
  web build then names the features of the screen where it happened — which is what makes it
  actionable at all. See [error reporting](../2-core/error-reporting.md).
- **DartWay Studio.** The app's bridge binding maps mounted specs onto `StudioFeatureInfo` and
  reports them on connect and on every navigation. Studio renders them live and stores none of it,
  so there is nothing that can drift from the code; a feature with a non-empty `knownIssues` is
  flagged in the catalog. See [the Studio bridge](../6-studio/studio-bridge.md).

Enumerating *every* feature of a project is not something a running app can do — Dart has no
reflection, so only mounted widgets are observable. That is a job for static analysis of the
sources.
