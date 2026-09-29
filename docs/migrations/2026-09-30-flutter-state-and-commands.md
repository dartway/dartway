---
title: "One way to hold state and one way to send a command: dartway check fails the rest"
affects:
  dartway_core_flutter: "0.21.0-dev.9"
  dartway_cli: "0.13.0"
---

## Who is affected

Every project whose Flutter package's `lib/` — `core/`, `shared/` and `ui_kit/` included — holds a
`StatefulWidget` (or `ConsumerStatefulWidget`, `StatefulHookWidget`, `StatefulHookConsumerWidget`),
a `setState`, a `StatefulBuilder`, or a `ChangeNotifier`/`ValueNotifier` it keeps state in:
`dart run dartway_cli:dartway check` fails on it now (`forbiddenStateHolder`). And every project
that sends `dw.command` from `widgets/`, `shared/` or `core/`, wraps a command in `try`/`catch`,
runs a `<Feature>Commands` method from a widget outside `dw.action`, or reads `DwCallOk`,
`DwCallRefused`, `DwCallFailed` or `valueOrThrow` in a widget (`forbiddenCommandCall`).

## What to change

**A widget's own state becomes hooks.** `StatefulWidget` → `HookWidget` (`ConsumerStatefulWidget` →
`HookConsumerWidget`), and what the `State` held moves into `build`:

    - late final TextEditingController _controller;
    - void initState() { … _controller = TextEditingController(text: widget.value); }
    - void dispose() { _controller.dispose(); … }
    + final controller = useTextEditingController(text: value);

`ScrollController`, `FocusNode`, `TabController` and `AnimationController` (its ticker mixin gone)
are `useScrollController`, `useFocusNode`, `useTabController`, `useAnimationController`. A `Timer`,
a `StreamSubscription` or an observer is a `useEffect` that returns its cleanup;
`WidgetsBindingObserver` for the lifecycle is `useOnAppLifecycleStateChange`. A flag is `useState`.
`didUpdateWidget` is a `useEffect(…, [prop])`, or `useValueChanged(prop, (old, _) { … })` when the
old value matters. A listener registered once that reads the latest props reads them through
`final latest = useRef(this)..value = this;`.

**The kit's copies from the skeleton.** A project's `lib/ui_kit/` holds its own copies of
`AppTextFormField` and `MultiLinkText` (and, from the example, a masked `PhoneTextField`). Replace
each file with the hooks version, keeping your own styling:
`template/dartway_starter_flutter/lib/ui_kit/1_essentials/app_text_form_field.dart` and
`multi_link_text.dart`, and `example/dartway_example_flutter/lib/ui_kit/2_frequent/phone_text_field.dart`
(the template's own `phone_text_field.dart` is stateless already). Their constructors are unchanged.
`AppTextFormField.fromStringNotifier` is gone with its `ValueNotifier`; a caller passes the value and
the setter of whoever holds it:

    - AppTextFormField.fromStringNotifier(valueNotifier: name, labelText: …)
    + AppTextFormField(value: name.value, onChanged: (v) => name.value = v, labelText: …)

with `name` a `useState('')` of the calling `HookWidget`, or `value: state.name,
onChanged: controller.editName` over a controller.

**A `StatefulBuilder` becomes a `HookBuilder`** (`HookConsumer` when it needs a `ref`), the state
inside it a `useState`:

    - StatefulBuilder(builder: (context, setState) => Checkbox(value: on, onChanged: (v) => setState(() => on = v!)))
    + HookBuilder(builder: (context) {
    +   final on = useState(false);
    +   return Checkbox(value: on.value, onChanged: (v) => on.value = v!);
    + })

**A mixin or an extension `on State<…>` that calls `setState`** (actions split out of a big page)
becomes a hook function of your own — a top-level `use…` that calls hooks and returns what the page
needs — called from the page's `build`:

    - mixin _UndoActions on State<ActivityLogPage> {
    -   UndoAction? pendingUndo;
    -   void offerUndo(UndoAction action) => setState(() => pendingUndo = action);
    - }
    + ({UndoAction? pending, void Function(UndoAction) offer}) useUndoOffer() {
    +   final pending = useState<UndoAction?>(null);
    +   return (pending: pending.value, offer: (action) => pending.value = action);
    + }
    + // in ActivityLogPage.build: final undo = useUndoOffer();

**A `State` in a file of its own** (a `part` of the widget's library) is a finding of its own. Convert
it with its widget: the fields become hooks in the widget's `build`, and the part file goes. Where
the `State` stays because an API needs it, the marker goes on each class it stands on — the widget's
and the `State`'s, whichever files they are in — and both are listed.

**State shared between widgets, or a flow with logic, becomes a controller**: a Riverpod `Notifier`
named `<Thing>Controller` in the feature's `logic/`, usually
`NotifierProvider.autoDispose.family<…Controller, …, Key>(…Controller.new)` keyed by what it is
about. A `ChangeNotifier` controller and a `ValueNotifier` field on a session object move there;
widgets `ref.watch` its state and call its methods through `ref.read(provider.notifier)`. A
`Notifier` of the project's not named `<Thing>Controller` is renamed with it (`AuthState` →
`AuthController`, `authControllerProvider`).

**An API that truly needs a `State` subclass or a `Listenable` of its own** keeps its class and takes
one line above it, with the reason:

    + // dw:allow-stateful DwAppRouter re-runs its guards on a Listenable
      class AppRouterState extends ChangeNotifier {

The skeleton's `lib/core/router/app_router_state.dart` needs exactly this line. Every run lists the
marked classes after the tally.

**Commands are sent from `logic/` and run inside `dw.action`.** App-wide wiring that no button
starts — registering a push token, a bootstrap step — stays in `lib/core/` (for example
`lib/core/push.dart`), which may send `dw.command` and read its result; everything a user triggers
moves to a feature. Move a `dw.command` out of a widget
into the feature's `logic/<feature>_commands.dart` (`<Feature>Commands`, command senders only) or
into the flow's controller, and wrap the call on the button:

    - onTap: () async { try { await dw.command(PayInvoice(invoiceId: id)); } catch (_) { … } },
    + onTap: dw.action((_) => InvoiceCardCommands.pay(invoice)),

A pure helper that sat on a `<Feature>Commands` class (building a patch from a draft) moves to a
file of its own in `logic/` — a call to `<Feature>Commands` from a widget outside `dw.action` fails.

**A widget reads no result.** A value the widget needs is unwrapped in `logic/` and arrives in the
follow-up, which runs on success only:

    - final result = await dw.action((_) => ACommands.create(title))(context);
    - if (result case DwCallOk(:final value)) selected.value = value.id;
    + // logic: static Future<Thing> create(String title) async =>
    + //     (await dw.command(CreateThing(title: title))).valueOrThrow;
    + await dw.action(
    +   (_) => ACommands.create(title),
    +   followUpIfMountedAction: (_, created) => selected.value = created.id,
    + )(context);

`followUpIfMountedAction: (_, result) { if (result is DwCallOk) … }` is just the call. A command
placed in `followUpIfMountedAction` is outside the action — only its first argument counts.

A refusal's text comes only from the app's catalogue, `DwFlutterConfig.refusalText` in `lib/core/`;
a flow that reacts to a refusal code (resetting a step) does so in its controller and returns the
result for `dw.action` to show. This one is **stated, not held**: the checker cannot tell a sentence
built from a refusal code from any other string — search your `logic/` for `refusal.code` and
`isCode(` used to pick a text, and move those texts into the catalogue. Commands sent through a
plugin's method or `dw.files` are not seen by the checker either; move them to `logic/` the same
way. `dw.files.getLink` and
`dw.files.upload` results are read in `logic/` the same way.

## How to check

`dart run dartway_cli:dartway check` in the Flutter package: no `forbiddenStateHolder` or
`forbiddenCommandCall`, and `🔓 Allowed by dw:allow-stateful` lists only the classes you meant.
