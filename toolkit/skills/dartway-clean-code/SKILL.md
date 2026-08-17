---
name: dartway-clean-code
description: >-
  DartwayTeam strict clean-code rules for ALL Flutter/Dart work (DartWay projects):
  self-explanatory naming (min 2 words), single responsibility per file
  (length is a soft signal: >200 lines a nudge, >350 a warning — split by
  responsibility, not by line count), never pass BuildContext or WidgetRef as params, no _buildXxx()
  widget-returning methods, no ref.invalidate, no GlobalKey tree lookups, no
  outer padding/margin inside a widget, no private widget classes in public
  feature files (and the one allowed kind has no State and no callbacks),
  a feature's constructor is its address (a model or an id) and not data its parent
  computed, the action written in the widget that owns the button and never handed
  down as a callback (no screen-wide busy flag),
  a Serverpod model rebuilt with copyWith and never by listing
  its fields, no default for a setting whose value belongs to the environment
  (sender address, provider key, admin identifier);
  plus SOLID, KISS, DRY, YAGNI, Law of Demeter, composition over
  inheritance, separation of concerns, fail-fast, tell-don't-ask, single source
  of truth, and tests for complex features / non-trivial bugfixes.
---

# Dartway Clean Code — the DartwayTeam rules

The set of mandatory rules for **any** Dart/Flutter code in **DartwayTeam** projects
(DartWay projects; dartway-first). These are not "recommendations" but a style contract — the
team deliberately keeps the code clean so the anti-patterns listed below never pile up.

## How to use this

- Check against the rules while **writing, generating, refactoring and reviewing** code — even a tiny snippet.
- Every block: briefly **why** the rule exists, then `❌` (how not to) and `✅` (how to).
- Before you hand code over — walk the [checklist](#checklist-before-handing-code-over) at the end.
- Part 1 — the team's hard rules (the least obvious, broken most often). Part 2 — general clean-code principles. Part 3 — tests for the complex stuff.

---

# Part 1. The team's hard rules

These rules are specific to the dartway stack and are broken most often. Keep them in mind first.

## 1.1 Naming: self-explanatory, at least 2 words

**Why:** a name must answer "what is this" without reading the type or the body. One-word and abstract names make the reader guess.

```dart
// ❌ what is this — a model? a widget? a dto?
class User {}
final model = UserProfileModel();
final data = fetchData();
final order2 = getNewOrder();        // order2 — what is that?
class DeliveryCard { final String s; final int n; final Function cb; }

// ✅ the name carries meaning
class UserProfileModel {}
final userProfile = UserProfileModel();
final fetchedProfile = fetchProfile();
final updatedOrder = getNewOrder();  // next to it: initialOrder
class DeliveryCard { final String deliveryStatus; final int itemsCount; final VoidCallback onTap; }
```

## 1.2 One responsibility per file; length is a soft guideline

**Why:** one file — one reason to change. A model + repository + state + UI in one file can be neither read nor reused.

**Length is the weakest of the indicators:** under 200 lines we say nothing; >200 — a reason to look closer; >350 — a warning, the file has probably collected several responsibilities. **A meaningful, coherent 300-line file beats a pointless chop** into pieces with no responsibility of their own. Split by responsibility, not by the line counter — all the more so because a feature file now also holds its `DwFeatureSpec`, and a good description costs a couple dozen lines.

```
// ❌ order_screen.dart: OrderItemModel + OrderRepository + OrderState + OrderListScreen

// ✅ separately:
//   models/order_item_model.dart
//   data/order_repository.dart
//   state/order_state.dart
//   ui/order_list_screen.dart

// ✅ also fine: a coherent 220-line screen with a single responsibility —
//    don't chop it into header_part_1.dart / header_part_2.dart to fit a limit
```

## 1.2a Imports: `../` means "next door", not "up the tree"

**Why:** a path made of dots says nothing. `'../../../../ui_kit/ui_kit.dart'` tells the reader neither
what is imported nor where it lives; `package:my_app_flutter/ui_kit/ui_kit.dart` tells both. The rule
is about **distance**, not about a blanket `package:` everywhere — a relative import of the file next
to you is the clearer one.

| What you import | How |
|---|---|
| Your own internals (`widgets/`, `logic/`) | relative — `import 'widgets/user_list_item.dart';` |
| A sibling feature in the same group | relative, one or two steps — `import '../user_form/user_form.dart';` |
| `core/`, `shared/`, `ui_kit/`, another zone | **`package:`** — `import 'package:my_app_flutter/ui_kit/ui_kit.dart';` |

**Two `../` is the limit**, and `deep_relative_import` (`dartway_lints`, warning) says so in the
editor. One or two steps read as "the feature next door"; three or four mean you left your group, and
a jump that big should be visible by name rather than counted in dots.

The limit doubles as a structure signal: if a *sibling* feature is suddenly four levels away, it is
not a sibling — either the group fell apart, or what you are importing belongs in `shared/` or in
`common/`.

## 1.3 Don't pass `BuildContext` / `WidgetRef` into services and logic

**Why:** service/domain code must not know about the UI and the widget lifecycle. It tears the layers apart and breeds "stale context".

```dart
// ❌ the service reaches into the UI
class PaymentService {
  void processPayment(BuildContext context, double amount) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    Navigator.of(context).pop();
  }
}
void loadUserData(WidgetRef ref) { ref.read(userProvider); }

// ✅ the service returns a result, the UI decides what to show
class PaymentService {
  Future<PaymentResult> processPayment(double amount) async { ... }
}
// in the widget: final result = await service.processPayment(amount);
//                if (result.isSuccess) { ScaffoldMessenger.of(context)...; Navigator.of(context).pop(); }
```

**The rule is about services, domain and logic — not about UI code whose job *is* the widget tree.**
A feature that opens as a sheet, a dialog or an overlay publishes itself as a **static method on its
own widget**, and `BuildContext` is its first parameter. That is the canonical shape, not an
exception squeezed past the rule:

```dart
// ✅ the feature's own widget owns how it is shown
class UserFormSheet extends StatelessWidget implements DwFeature {
  static Future<void> showCreate(BuildContext context) =>
      context.showAppBottomSheet(child: const UserFormSheet());
  static Future<void> showEdit(BuildContext context, UserProfile userProfile) => ...;
}

// ❌ the same call, moved onto someone else's type to dodge the rule
extension UserFormExtension on BuildContext {
  Future<void> showCreateUserForm() => showAppBottomSheet(child: const UserForm());
}
```

**An `extension on BuildContext` that opens your own screens is an antipattern.** It reads as
compliance and costs more than the parameter ever would: the feature ends up with two public files
instead of one (the extension at the root, the widget hidden in `widgets/`), the entry point stops
being the widget, and `context.showCreateUserForm()` no longer says which feature it opens.

What this does **not** forbid: the framework's navigation extensions (`context.pushTo`,
`context.goNamed`) are the supported way to move between routes, and the UI Kit's own presentation
primitives (`context.showAppBottomSheet(child: …)`, theme and l10n accessors) are exactly where a
`BuildContext` extension belongs — they take any child and name no feature. The line is whether the
extension names **a screen of yours**: presentation chrome on `BuildContext` is fine, a feature on
`BuildContext` is not.

## 1.4 No `_buildXxx()` methods that return a widget

**Why:** private build methods get no `const`, are not reused, and break rebuild boundaries. A widget is a class, not a method.

```dart
// ❌
class ProfilePage extends StatelessWidget {
  Widget _buildHeader() => Container(...);
  Widget _buildStats(int orders, int reviews) => Row(...);
  @override
  Widget build(BuildContext context) => Column(children: [_buildHeader(), _buildStats(10, 5)]);
}

// ✅ separate widget classes
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Column(children: [ProfileHeader(), ProfileStats(orders: 10, reviews: 5)]);
}
// ProfileHeader / ProfileStats — each in its own file (see 1.8)
```

## 1.3a No functions outside classes — only class methods or extensions

**Why:** a top-level function is a name dangling in the library namespace: you can't find it from the type it works with, the IDE won't suggest it after a dot, and you have to import it separately from whatever it belongs to. Logic bound to a type belongs to that type.

```dart
// ❌ a free function — the name doesn't show what it relates to
CourseLockState resolveCourseLockState({required UserCourse? userCourse, ...}) { ... }

// ✅ a factory on the type itself — found through the dot from it
class CourseLockState {
  factory CourseLockState.resolve({required UserCourse? userCourse, ...}) { ... }
}

// ✅ or an extension, if the type is someone else's
extension UserCourseAccess on UserCourse {
  bool isExpiredAt(DateTime now) => accessUntil.isBefore(now);
}
```

**Where things go:** creates a value of its own type → **factory constructor**; answers a question about an existing value → **method or getter**; the type is someone else's (a model from the generated client, a framework type) → **extension**; you need a shared utility with no type of its own → a static method on an owner class, not a free function.

**Exactly two exceptions, both forced:**

- **codegen provider entry points** — if the project does use `riverpod_generator` after all (by default we don't, see the codegen policy in `CLAUDE.md`): a `@riverpod` function must be top-level, the generator requires it;
- **`main()`** and similar runtime entry points.

## 1.3c A private widget method that computes data is an extension in `logic/`

**Why:** rule 1.4 forbids `_buildXxx()` that return widgets, and this is its data half. A private
widget method that **transforms the domain** (filters a list, maps models into kit parameters,
computes a derived value) is the same logic hidden from the type it works with: you can't find it
from the model, can't reuse it in a neighbouring widget, and can't cover it with a test without
spinning up the whole tree.

```dart
// ❌ domain mapping hidden inside a private widget method
class AdminChatsFiltersBar extends ConsumerWidget {
  List<AdminSelectOption<int>> _postOptions(List<ChatPostListDto> posts) => [
    for (final post in posts)
      if (post.commentToPostId == null && post.title != null)
        AdminSelectOption(value: post.id, label: post.title!),
  ].take(20).toList();
}

// ✅ an extension next to the feature, in logic/ — found from the list through the dot
extension ChatPostFilterOptions on List<ChatPostListDto> {
  List<AdminSelectOption<int>> get commentParentOptions => [ ... ];
}

// in the widget: options: posts.commentParentOptions
```

**The boundary is simple:** the method builds a widget → a separate widget class (1.4); the method
computes data → an extension in the feature's `logic/` (1.3a). What stays in `build` is a call through the dot.

A getter that reads only the widget's own fields and computes nothing
(`bool get _hasImage => imageUrl?.isNotEmpty ?? false`) needs no extraction — it is about the widget itself.

## 1.3b Write a state data class by hand, not with `freezed`

`copyWith` and `==` over five or six fields are twenty lines, written once and read without any
extra knowledge. In exchange `freezed` charges you `build_runner` in the edit loop and a generated file
next to every class.

The exception where the generator really pays off: **union types** (several constructors of one
sealed type with an exhaustive `switch`). Bringing it in for a single data class — no.

## 1.4a A widget in a local variable used once is the same `_buildXxx()`

**Why:** `final content = Column(...)` that is inserted below in a single place is the same tree
break as `_buildXxx()`: the reader has to keep in mind where the variable is declared and where it
is used. Inline it right where it belongs.

```dart
// ❌
final content = Column(children: [...]);
return AppBottomSheetPageBody(child: content);

// ✅
return AppBottomSheetPageBody(child: Column(children: [...]));
```

**Exception:** a variable is worth introducing if it is used **twice or more** (two branches of a
condition) or if between the declaration and the use there is a computation you would otherwise have to repeat.

## 1.4b We don't carry commented-out code

Delete it. History lives in git, while a comment rots silently: one file in a production project held 119
commented-out lines out of 306 — a whole widget written against an API that no longer
exists. You can't revive that anyway, and everyone has to read it.

## 1.5 No `ref.invalidate(...)` for refreshing

**Why:** `invalidate` is a blunt reset that takes down related providers and makes the UI flicker. Update the state through the proper state mechanism (in dartway — refresh on `DwRepository`/the state provider, re-fetching the data).

```dart
// ❌
onPressed: () { ref.invalidate(cartProvider); ref.invalidate(userProvider); }

// ✅ explicit state refresh
onPressed: () => ref.read(cartStateProvider.notifier).refresh(),
```

## 1.6 Don't look widgets up in the tree via `GlobalKey`

**Why:** `GlobalKey().currentState` reaches into someone else's state past state management. Drive the data through a provider/controller instead of poking the tree.

```dart
// ❌
final nameFieldKey = GlobalKey<FormFieldState>();
void validate() => nameFieldKey.currentState?.validate();

// ✅ form state lives in a provider/controller; validate by data, not by widget
final isNameValid = ref.read(signUpFormProvider).isNameValid;
```

## 1.7 No outer padding (`padding`/`margin`) inside a widget

**Why:** outer padding is the responsibility of the **parent** that places the widget. If a widget gives itself outer margins, it can't be reused in another context.

```dart
// ❌ the widget gives itself outer padding
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Container(...));
}
class ActionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(margin: const EdgeInsets.all(12), child: ElevatedButton(...)); // margin = outer padding
}

// ✅ the widget draws only itself; the parent sets the padding
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(...); // inner content padding is fine
}
// parent: Padding(padding: ..., child: ProductCard())  /  ListView(padding: ...)
```

**The rule holds when refactoring someone else's code too.** Rewriting a widget — the outer `Padding`
is not "kept as it was", it moves to the caller (`itemBuilder`, `Column`, `ListView.padding`).
Otherwise the refactoring legalizes the violation: the file got cleaner, and the padding stayed inside.

## 1.7a A widget doesn't decide how much space it takes

The same principle as 1.7, but about size: **how much space a widget gets is the parent's call.**
A widget that inflates itself breaks on the first reuse — and it breaks at runtime, the analyzer
says nothing about it.

```dart
// ❌ the widget assigns itself a size and demands a particular parent
Widget build(BuildContext context) => Expanded(child: content);         // will crash outside Row/Column
Widget build(BuildContext context) => SizedBox(height: double.infinity, child: content);

// ✅ the widget draws its content; space is given by whoever inserted it
Widget build(BuildContext context) => content;
// parent: Expanded(child: MyWidget())  /  SizedBox(height: 200, child: MyWidget())
```

A special trap: **`Expanded` requires a flex parent**. A widget living in a screen's `Column` gets
inserted by the very same code into a bottom sheet, a dialog or a `SingleChildScrollView` — and the app
crashes for the user. Before changing a widget's sizing wrapper, walk **all** its callers.

The exception is a widget whose whole point is its size (`AppEventCard.compact` with the feed's fixed width):
then the size is declared in the kit and visible from the constructor name, not hidden in `build`.

## 1.8 A widget with standalone value is a public class in its own file

**Why:** `_MessageBubble` in `chat_message_list.dart` is a separate entity of the feature (message rendering, its own behavior) that was hidden as private: it can't be reused or tested from the outside. Extract such things into their own file as a public class.

```dart
// ❌ chat_message_list.dart contains class _MessageBubble and class _DateSeparator
// ✅ message_bubble.dart -> class MessageBubble; date_separator.dart -> class DateSeparator
```

**Exception — a slice of layout extracted so `build` stops growing**, used once in the very same
file (e.g. `_CounterTile` inside `admin_counters.dart`). It has no value for reuse or a separate
test, and moving it into a public file is pure noise.

**The exception is bounded by two facts about the class, not by how trivial it looks.** "Trivial" is
judged by whoever has just written the thing, and it stretches: a 95-line class with its own `State`,
its own `TextEditingController` and its own rule about what may not be submitted has been let
through under this exception in a live project. It was unreachable from a test and unreachable from
the widget next door that needed the same behaviour. So:

- **a private widget class has no `State`.** State is behaviour, behaviour gets tested, and what
  gets tested has a name and a file. `_Foo extends StatefulWidget` inside a feature file is the rule
  being broken, whatever its length;
- **a private widget class takes no callbacks.** A callback parameter means something is being
  threaded through it from the parent — so it is not a detail of this file's layout, it is a piece
  of the feature that was left unnamed (see §1.9b: the widget that owns the button owns the action).

What is left over is a `StatelessWidget` with no callbacks, which is honestly trivial and can be
recognised as such without taste.

## 1.9 Don't create a pass-through widget: if it decides nothing, inline the kit widget

**Why:** a pass-through is a class that only re-assembles its own parameters into a single kit widget. The reader has to open an extra file just to learn there is nothing in it, and the feature grows a folder of such files.

```dart
// ❌ course_locked_stub_card.dart — every field goes straight out as is
class CourseLockedStubCard extends StatelessWidget {
  const CourseLockedStubCard({required this.child, required this.topInset});
  ...
  Widget build(context) => Padding(
    padding: EdgeInsets.only(top: topInset),
    child: ChatCardContainer.bottomSheetSurface(child: child),
  );
}

// ✅ the same thing right at the call site — the file and the class simply don't exist
```

**How to tell a pass-through from a widget you need — by what it does with the domain:**

- **a mapper** turns a model or a domain enum into kit parameters (`CommunityEventCard` — a model into texts and an image url; picking a constructor by `CourseLockReason`). That is work, and it must live in the feature: the kit knows nothing about models. **We keep it;**
- **a pass-through** forwards its own parameters and adds at most a padding constant to them. There is no work. **We delete it and inline the kit widget.**

The sign that gives a pass-through away at the door: its only import is `ui_kit.dart` — it knows nothing about the domain, so it has nothing to decide.

**If such a widget really is needed by many** (the same wrapper in five places) — that is no reason to breed a pass-through in the feature, it is a reason to add a **constructor in the kit** (`ChatCardContainer.bottomSheetSurface`): the meaning moves to where the look lives.

## 1.9a A feature's constructor is its address, not its data

**Why:** nothing in this contract says what a widget may accept, and that gap is wide enough to
drive a React app through it. A feature taking fifteen parameters — four ready-made lists, a couple
of maps and six callbacks — passes naming, passes file length (the file was 182 lines), passes
`_buildXxx`, passes every rule above. And it can only ever be placed inside the one parent that
knows how to assemble its arguments.

**A feature is handed what names its subject** — a model, or an identifier of one. Everything else
it asks for itself: the same `dw.repo` provider its parent watched (§3 of `dartway-data-layer` —
identical configs are one request, so asking again costs nothing), an extension on the model it was
already given, its own local state.

**The question is not "how many parameters" but "could this widget have got it itself?"**

| In the signature | Could it? | Verdict |
|---|---|---|
| A list the parent computed off a model the child also receives | yes — an extension on that model | remove |
| A `Map<int, List<Something>>` assembled at the top of the screen and passed down four levels | yes — each level asks for its own | remove |
| A flag derived from a model already passed (`hasOpenWork`, `isEditable`) | yes — a getter on the model | remove |
| The model itself, its parent, an id | no | keep |
| One callback for a decision only the parent can make (§1.9b) | no | keep |

**The count is a symptom, not the rule.** Three parameters of which two are derived from the first
are worse than five independent ones — the two derived ones are a claim that the child cannot be
trusted to read its own subject.

```dart
// ❌ fifteen parameters: four lists, a type, a project, a busy flag, seven callbacks —
//    placeable nowhere except inside the parent that assembles them
TicketWorkCard(
  task: task, questions: questions, corrections: corrections,
  ticketType: ticket.ticketType, project: project, taskRuns: runs,
  actions: availableActions, working: busy,
  onRun: ..., onAccept: ..., onRework: ..., onCancel: ...,
  onAnswer: ..., onDismiss: ..., onRetry: ...,
);

// ✅ three: everything else follows from the ticket, which arrived as one graph
TicketWorkCard(ticket: ticket, task: task, project: project);
```

## 1.9b The action lives where the button is

**Why:** `dw.action` is described as the thing you write an action *with*, and nowhere as *where* it
lives — so handing a callback downwards is nobody's violation. In a live feature the cancelling of
one question travelled from the button to `dw.repo.saveModel` through **six** hand-offs, and every
one of them was a parameter on a widget that otherwise had no reason to know about saving.

**A widget with a button does the thing the button promises.** `dw.action` wraps the call right
there, in the widget the user pressed:

```dart
// ❌ the button is here, the write is five levels up: every widget in between
//    carries onSubmit/onDismiss it does nothing with
class TicketAnswerField extends StatelessWidget {
  const TicketAnswerField({
    required this.question,
    required this.onSubmit,
    required this.onDismiss,
    super.key,
  });
}

// ✅ the widget saves what it collected — nobody above it has to know it exists
class TicketAnswerField extends ConsumerWidget {
  const TicketAnswerField({required this.question, super.key});
  // in build: DwActionBuilder(
  //   action: dw.action((_) => question.answerWith(controller.text)),
  //   builder: (context, onPressed, busy) => ...,   // busy is this button's own
  // )
}
```

**A callback is legitimate when the parent decides something the child cannot know** — where to go
after success, whether the dialog closes, which route to leave on. There is normally **one** such
callback on a feature, not six:

```dart
/// The one callback that arrives from above, and it earns its place: moving the
/// stage carries the ticket into another column, so the card has to close —
/// and only the card knows it is a card.
final VoidCallback onMoved;
```

**There is no screen-wide `busy` flag.** `DwActionBuilder` computes busy for each button separately,
under that button. A flag held at the top does not merely duplicate it — it lies: in a live app,
pressing "accept" on one row greyed out "run" on every other row on the screen. If you find yourself
adding `working: busy` to a constructor, the action is in the wrong place.

## 1.10 A Serverpod model is rebuilt with `copyWith` only

**Why:** calling the generated constructor and listing the fields is for **creating a new row**. A field
with `default=`, and any nullable field, is an **optional argument** — so a field you forget is not a
compile error, it is a silent substitution of the default.

That is not a hypothetical. In a real project a `priority` field was reset to `medium` on **every**
edit of the record it belonged to — the agent's draft, the manual correction, the approval of the
requirements — because one method rebuilt the model by naming its fields and the field had been added
after that method was written. Priority is what the backlog is sorted by. Neither the compiler, nor a
test, nor a review can see this.

```dart
// ❌ a rebuild by naming the fields — `priority` is not in the list, so it silently becomes the default
Future<void> approve(FeatureRequest request) => repository.save(FeatureRequest(
      id: request.id,
      title: request.title,
      description: request.description,
      status: RequestStatus.approved,
    ));

// ✅ copyWith — a field nobody touched keeps its value, whatever fields the model grows later
Future<void> approve(FeatureRequest request) =>
    repository.save(request.copyWith(status: RequestStatus.approved));
```

**The ban takes nothing away.** The one reason to reach for a field-by-field rebuild — "I need to
clear a nullable field, and `copyWith` treats null as *not passed*" — does not hold for a generated
Serverpod `copyWith`: it takes `Object? field = _Undefined` and tests `field is T? ? field : this.field`.
Pass `null` explicitly and the field is cleared; leave it out and it is kept.

```dart
// ✅ clearing a field is copyWith's job too
request.copyWith(assigneeProfileId: null);
```

**`model_rebuild_by_constructor`** (`dartway_lints`, warning) says this in the editor: a constructor
call on a Serverpod model that is passed a non-null `id:` is a rebuild, because a row being created
never carries an id — it comes back from the database. The one legitimate exception in a DartWay app
is `core/default_models.dart`, where mock instances are invented from nothing with a synthetic id;
it carries an `// ignore_for_file:` that says so.

**A doc comment is not a rule.** The method in that project had an honest request written above it —
*"anything added to the model belongs here too"* — and it changed nothing, because the field was
added by a different task that never opened that file. A rule that lives in a comment at the other
end of the system does not exist.

**The same failure, one level up: an enumeration written out by hand.** If a field-by-field pass over
something really is unavoidable, build it by **iterating the values**, not by listing them — then a
new member arrives everywhere on its own.

```dart
// ❌ a hand-written list — a new BookingStatus is added, and this bar quietly stops showing it
final filters = [
  BookingFilterChip(status: BookingStatus.pending),
  BookingFilterChip(status: BookingStatus.confirmed),
];

// ✅ driven by the enum — the new value is there the moment it is declared
final filters = [
  for (final status in BookingStatus.values) BookingFilterChip(status: status),
];
```

Where a per-value *decision* is needed rather than a uniform pass, the tool is an exhaustive
`switch` **without a `default:`** — Dart then makes the missing branch a compile error. A map literal
or an `if`/`else if` chain over the same values gives you nothing.

---

## 1.11 A setting whose value belongs to the environment has no default

Sender address, provider key, webhook URL, bucket name, the identifier of the first administrator —
these are not preferences with a sensible starting point. Each one is a **credential of this
deployment**, and the only correct value is the one this deployment was given.

Give such a setting a default and an unfilled key stops being an error. It becomes quiet work with
somebody else's credentials: mail leaves from an address the project does not own, a webhook posts
to a stranger's endpoint, and nothing anywhere says so. The failure is not that it breaks — it is
that it *works*, plausibly, pointing at the wrong place.

```dart
// ❌ the project that forgets to configure this sends mail as someone else
final senderAddress = passwords['senderAddress'] ?? 'noreply@example.com';

// ✅ unset is unset, and it says so where it is read
final senderAddress = passwords['senderAddress'] ??
    (throw StateError('senderAddress missing in passwords'));
```

Empty and an explicit error beats a plausible foreign value. Read the setting at the point of use
and fail there, or check it on boot — either is fine; what is not fine is a fallback that hides the
gap.

The framework's own template follows this: `bootstrapAdminIdentifier` is deliberately left without
a default. A default administrator in a public template would mean every project that forgot to
change it has an administrator whose channel a stranger controls.

Preferences with a genuine neutral value — a page size, a timeout, a retry count — are not this
rule. The test is whether the value is *about this deployment*. If a wrong value would point the
system at somebody else, there is no default to give.

---

# Part 2. Clean code principles

Well-known principles. Here — how they look in Dart/Flutter and what to avoid.

## 2.1 SRP — Single Responsibility

**Why:** a class that loads data, caches, validates, formats and shows a SnackBar cannot be changed safely.

```dart
// ❌ OrderManager: fetchOrdersFromApi + cacheOrder + validateOrder + formatPrice + trackAnalytics + showSuccess(context)
// ✅ OrderRepository (data) | OrderCache | OrderValidator (domain) | PriceFormatter (ui_kit) | AnalyticsService
```

## 2.2 OCP — Open/Closed

**Why:** adding a new type must not require editing old code. Extend with an abstraction, not with another `if/switch` branch.

```dart
// ❌ a new channel means going inside send()
void send(NotificationType type, String message) {
  if (type == email) {...} else if (type == push) {...} else if (type == telegram) {...}
}
// ✅ abstract class NotificationChannel { void send(String message); }
//    EmailChannel / PushChannel / TelegramChannel — a new channel = a new class, send() is untouched
```

## 2.3 LSP — Liskov Substitution

**Why:** a subclass must work everywhere the parent works. Throwing `UnsupportedError` from an overridden method is a broken contract.

```dart
// ❌ class CachedReadOnlyRepository extends ReadOnlyRepository { @override save(x) => throw UnsupportedError(); }
// ✅ split the interfaces: abstract Readable { getAll(); } / abstract Writable { save(x); }
```

## 2.4 ISP — Interface Segregation

**Why:** a "fat" interface forces you to implement what you don't need through stubs/exceptions.

```dart
// ❌ abstract Worker { writeCode(); reviewCode(); designUI(); manageTeam(); deployToProduction(); }
//    class JuniorDeveloper implements Worker { designUI() => throw UnimplementedError(); ... }
// ✅ narrow roles: Coder / Reviewer / Designer / Manager — implement only the ones you need
```

## 2.5 DIP — Dependency Inversion

**Why:** high-level code must depend on an abstraction, not on a concrete implementation. A Firebase→Supabase move must not touch the screens.

```dart
// ❌ final authService = FirebaseAuthService();    // nailed to the implementation
// ✅ depend on abstract class AuthService; inject the concrete one through a provider/DI
final authService = ref.read(authServiceProvider); // -> FirebaseAuthService under the hood
```

## 2.6 KISS — simpler

**Why:** extra complexity = extra bugs. Don't write 15 lines and a "strategy pattern" where one line is enough.

```dart
// ❌ 15 lines with a loop just to check emptiness;  Strategy+Context just to join two strings
// ✅ items?.isEmpty ?? true;      '$first $last';
// ❌ Builder→LayoutBuilder→AnimatedContainer→MediaQuery→DefaultTextStyle for a single Text
// ✅ Text(text)
```

## 2.7 DRY — don't repeat yourself

**Why:** a copy-pasted card/logic diverges at the very first change. Extract into a shared widget / extension / domain.

```dart
// ❌ three identical Container cards in a row via Ctrl+C; the same mapping in ViewModel and ExportService
// ✅ OrderStatusCard(title: ..., status: ..., color: ...);
//    extension ActiveOrderFilter on List<OrderItemModel> { List<String> get exportTitles => ...; }
```

## 2.8 YAGNI — don't build for later

**Why:** 20 fields "in case they come in handy" and an abstraction with a single implementation are dead weight you have to maintain.

```dart
// ❌ UserProfileState with tiktokHandle/linkedInUrl/isInfluencer/... when only name and email are used
// ❌ abstract BaseAnalyticsProvider + a single FirebaseAnalyticsProvider
// ✅ keep only the real fields; introduce the abstraction when a second provider appears
```

## 2.9 Law of Demeter — don't reach into someone else's guts

**Why:** the chain `a.b.c.d` means the caller knows the entire internal structure of other objects. Any link will break.

```dart
// ❌ company.department.team.teamLead.getEmail();
// ❌ ref.read(appStateProvider).currentSession.activeUser.profile.displayName;
// ✅ company.teamLeadEmail;     ref.watch(currentUserDisplayNameProvider);
```

## 2.10 Composition over Inheritance

**Why:** a 5-level `AnimatedShadowedRoundedStyledWidget` hierarchy is unreadable and undebuggable. Assemble behavior out of parts.

```dart
// ❌ Base -> Styled -> RoundedStyled -> ShadowedRoundedStyled -> Animated...
// ✅ composition: AnimatedOpacity(child: DecoratedBox(child: ClipRRect(child: child)))  / mixins / parameters
```

## 2.11 Separation of Concerns

**Why:** a widget with an HTTP request, a discount calculation and validation can be neither tested nor reused. The UI only displays.

```dart
// ❌ _ProductPageState: http.get(...) + calculateDiscount(...) + canAddToCart(...) right in the State
// ✅ requests -> repository; calculations/rules -> domain; State only holds and shows the data
```

## 2.12 Fail Fast — don't swallow errors

**Why:** an empty `catch` hides a bug forever. Log it, rethrow it, or handle the specific error.

```dart
// ❌ try { ... } catch (e) { return null; }      try { ... } catch (_) {}
// ✅ try { ... } on ApiException catch (e, st) { log.error(e, st); rethrow; }
```

## 2.13 Avoid Premature Optimization

**Why:** a custom LRU cache for 50 users is complexity without a reason. Measure first, optimize after.

```dart
// ❌ a hand-rolled LRU with _accessOrder and _maxCacheSize = 1000 for a list of 50 names
// ✅ a plain Map (or no cache at all) until the profiler shows a real problem
```

## 2.14 Tell, Don't Ask

**Why:** don't pull an object's fields out to compute outside — let the object compute itself. Logic lives next to the data.

```dart
// ❌ outside: sum up cart.itemPrices, subtract cart.promoDiscount, clamp...
// ✅ cart.total;   // ShoppingCart itself knows how to compute its total
```

## 2.15 Avoid God Object

**Why:** a class holding auth + orders + cart + profile + settings + navigation + analytics is the whole app in one file.

```dart
// ❌ class AppController { login(); loadOrders(); addToCart(); updateProfile(); toggleTheme(); goToHome(); trackEvent(); }
// ✅ AuthService | OrderRepository | CartState | ProfileService | SettingsState | Router | AnalyticsService
```

## 2.16 Avoid Magic Numbers / Strings

**Why:** `if (distance > 50)` and `status == 'pndng'` — the compiler catches no typo, the meaning of the number is unknown. Names and enums.

```dart
// ❌ return weight * 3.5 + 299;          if (status == 'pndng') ...
// ✅ static const longDistanceBaseFee = 299;   enum OrderStatus { pending, delivered, inTransit }
//    switch (status) { case OrderStatus.pending: ... }   // the compiler demands every branch is covered
```

## 2.17 Single Source of Truth

**Why:** a local copy of global state falls out of sync — you forget to write it back, and the UI lies.

```dart
// ❌ initState() { userName = GlobalAppState.userName; }  save() { GlobalAppState.userName = userName; }
// ✅ the widget reads and writes directly through the provider — one source of truth
final userName = ref.watch(dw.requireUserProfileProvider.select((p) => p.name));
```

---

# Part 3. Tests for the complex stuff

**Why:** complex logic can't be checked "by eye" — it breaks on edge cases and quietly degrades over time. A test pins down the expected behavior and catches regressions. The threshold is **behavior complexity**, not the mere fact of a change.

**What we cover with tests:**
- Complex features and non-trivial logic — calculations, business rules, state machines, money (e.g. wallet/payments).
- Edge cases and rollback/degradation scenarios ("downgrade": a business profile expired → the badge was removed, a subscription was cancelled, the balance went negative).
- Any bugfix of non-trivial behavior.

**What we do NOT test:** cosmetics — recolored a button, fixed a padding, renamed something. A test for the sake of a checkbox contradicts KISS/YAGNI.

**A bugfix is strictly "cause → fix":**
1. First a test that **reproduces the bug**. It fails — that failure is the localization of the cause.
2. You fix the code until the test goes green.
3. The test stays in the repo as a regression guard, so the bug does not come back.

**The test level follows where the behavior lives** (the level itself is not dogma):
- Logic (domain/services/state/repository) → a unit test. Most of it lands here — the logic is extracted out of widgets anyway (see 2.11 SoC).
- Behavior in the UI → a widget test for the key scenario.

```dart
// ❌ a complex wallet calculation is patched "by eye", no tests — users catch the regression
// ❌ a bugfix without a test: the cause is not pinned down, in a month the bug is back

// ✅ reproduce-first bugfix: a red test on the cause → fix → it stays as a regression test
test('wallet does not go negative when charged more than its balance', () {
  final wallet = Wallet(balance: 100);
  expect(() => wallet.charge(150), throwsA(isA<InsufficientFundsException>()));
});
```

---

## Capstone: everything wrong → how it should be

```dart
// ❌ 1-word name + build method + context/ref as parameters + invalidate + outer padding + duplication
class Page extends ConsumerWidget {
  Widget _buildItem(BuildContext context, WidgetRef ref, dynamic d) => GestureDetector(
        onTap: () { ref.invalidate(someProvider); Navigator.of(context).pop(); },
        child: Padding(padding: const EdgeInsets.all(16), child: Text(d.toString())),
      );
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(children: [_buildItem(context, ref, 'one'), _buildItem(context, ref, 'two')]);
}

// ✅ meaningful name + separate widget class + data through state + padding outside + list without copy-paste
class ItemsListPage extends ConsumerWidget {
  const ItemsListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsStateProvider);
    return Column(children: [for (final item in items) ItemTile(item: item)]);
  }
}
// item_tile.dart -> class ItemTile (outer padding set by the parent/ListView, refresh through the notifier)
```

---

## Checklist before handing code over

- [ ] **Names** are meaningful, ≥2 words; no `model`/`data`/`list`/`s`/`n`/`cb`/`order2`.
- [ ] **File** — one responsibility (model/repository/state/UI separately); >200 lines — look closer, >350 — probably time to split (but by responsibility, not by the counter).
- [ ] **No functions outside classes** — factory/method/extension; the only exceptions are `@riverpod` entry points and `main()` (§1.3a).
- [ ] **No widget in a variable used once** (§1.4a) and **no commented-out code** (§1.4b).
- [ ] **No pass-through widgets** — a class that only forwards its own parameters into a kit widget and knows nothing about the domain (`ui_kit.dart` its only import) is not created: inline the kit widget, and turn a repeating wrapper into a kit constructor (§1.9).
- [ ] **A feature's constructor is its address** — a model or an id, not lists/maps/flags its parent computed for it. For every parameter: could the widget have got this itself? (§1.9a).
- [ ] **The action is written in the widget that owns the button** (`dw.action` right there), not handed down as a callback; a callback stays only for a decision the parent alone can make. **No screen-wide `busy`** — `DwActionBuilder` counts it per button (§1.9b).
- [ ] **No** `BuildContext`/`WidgetRef` in the parameters of services and functions — and **no `extension on BuildContext` that opens the app's own screens**: showing a feature is a static method on that feature's widget (§1.3).
- [ ] **No** `_buildXxx()` methods returning a widget — those are separate widget classes (§1.4).
- [ ] **No** private widget methods that transform the domain — those are extensions in the feature's `logic/` (§1.3c).
- [ ] **No** `ref.invalidate(...)` — refresh through the state.
- [ ] **No** `GlobalKey` for looking widgets up in the tree.
- [ ] **No** outer `padding`/`margin` inside a widget — the parent sets the padding (§1.7). When refactoring someone else's widget the outer padding moves to the caller instead of being "kept as it was".
- [ ] **No** `Expanded`/`SizedBox(…: double.infinity)` at the root of `build` — the parent gives the widget its space (§1.7a).
- [ ] **No** private widget classes (`_Foo`) in public feature files. The one exception is a slice of layout — so **no `State` and no callbacks** on a private widget class (§1.8).
- [ ] **A Serverpod model is rebuilt with `copyWith`**, never by listing its fields in the constructor — a field with `default=` or a nullable one is optional, so a forgotten one is a silent default, not an error. Clearing a nullable field is `copyWith(field: null)` (§1.10). An unavoidable enumeration is driven by `Enum.values` or an exhaustive `switch`, not written out by hand.
- [ ] **A setting whose value belongs to the environment has no default** — sender address, provider key, webhook URL, admin identifier. An unfilled key must be an error, not quiet work with somebody else's credentials (§1.11).
- [ ] **A building block** — a widget with no product behaviour to describe — lives in `lib/shared/` with a doc comment, not in a zone with an empty `DwFeatureSpec`.
- [ ] **Imports:** own internals and sibling features are relative and no deeper than two `../`; `core`/`data`/`domain`/`shared`/`ui_kit`/another zone are `package:` (§1.2a).
- [ ] **The provider is the first thing in its file** (or lives in the feature's root file), not appended after the notifier that implements it.
- [ ] **The complex stuff** (non-trivial logic/behavior, money, "downgrade" rollbacks) is covered by a test; a bugfix — first a failing test on the cause, then the fix. We don't test cosmetics.
- [ ] SOLID, KISS, DRY, YAGNI, Law of Demeter are respected.
- [ ] Composition instead of deep inheritance; logic is not in the UI (SoC).
- [ ] Errors are not swallowed (fail fast); no premature optimization.
- [ ] Tell-don't-ask; no god objects; no magic numbers/strings (enum/const).
- [ ] One source of truth — no local copies of global state.
