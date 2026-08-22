# What happens when the user taps?

Every user action in an app repeats the same five steps: ask for confirmation if it is destructive,
run the work, tell the user it worked, do the follow-up, and report it properly if it failed.
Written by hand, those five steps are copy-pasted into every widget, and each copy forgets a
different one — usually the last two.

DartWay splits the problem in two:

- **`DwUiAction` — what the action does.** Confirmation, notifications, follow-up, error reporting.
  Built with `dw.action(...)`.
- **`DwActionBuilder` — what happens in the UI while it runs.** The in-flight flag, the suppressed
  second tap, form validation, focus.

The framework ships no button. It ships the two mechanisms a button would otherwise have to contain.

## `dw.action` returns a value, not a callback

```dart
final bookAction = dw.action(
  (context) => dw.repo.saveModel(
    SessionBooking(
      clubSessionId: session.id!,
      clientProfileId: ref.readUserProfile.id!,
      status: BookingStatus.booked,
      createdAt: DateTime.now(),
    ),
  ),
  onSuccessNotification: l10n.youAreBooked,
);
```

`bookAction` is a `DwUiAction<SessionBooking>` — **not** a `VoidCallback`. You cannot hand it to
`onPressed:` and the compiler will tell you so. That is the point, for two reasons:

- **it needs a `BuildContext`.** The confirmation dialog, the follow-up and any navigation inside
  the action all need the tree. A `DwUiAction` is invoked as `action(context)`, which is why the
  callback you write receives a `context` too (use `(_)` when you do not need it).
- **it does not know whether it is running.** "In flight" is UI state — it belongs to the widget
  that was tapped, not to a value you can store in a field and pass around. Keeping it out of
  `DwUiAction` is what lets the same action be reused behind a button on one screen and a list tile
  on another.

So a `DwUiAction` is a value: build it, store it, pass it to a widget, hand it to a kit constructor
(`AppButton.primary(label, onTap: bookAction)`). It runs when something calls it with a context.

## What `dw.action` wraps around your callback

In order, on every run:

1. **Confirmation.** With `confirmation:` set, `dw.confirm` is shown first. Anything other than
   `true` — declined, dismissed, context unmounted — stops here: **no work, no notifications, no
   follow-up**, and the action returns `null`.
2. **Your callback**, awaited.
3. **`onSuccessNotification`** through `dw.notify.success` if set.
4. **`customNotificationBuilder(value)`** — a notification derived from the result; returning `null`
   posts nothing.
5. **`followUpIfMountedAction(context, value)`** — navigation, a sheet to close, a scroll to reset.
   Skipped if the context is gone, which is the check everybody forgets in a hand-written handler.

If anything throws, none of 3–5 run and instead:

- `onErrorNotification` is shown if set;
- your `onError(error, stackTrace)` hook is called if set;
- `dw.handleError(...)` fires with `source: DwErrorSource.uiAction`.

**The action then returns `null` rather than rethrowing.** A failed action never crashes the screen
— but it also means the caller cannot tell failure from a declined confirmation. If the caller must
know, return a value from the callback and check it.

## Confirmation

```dart
dw.action(
  (_) => dw.repo.saveModel(user.copyWith(role: role)),
  label: 'changeUserRole',
  confirmation: DwUiConfirmation(
    context.l10n.confirmChangeRole(displayName, context.l10n.roleName(role.name)),
  ),
)(context);
```

`DwUiConfirmation` is declarative: `message`, optional `title`, `confirmLabel` / `cancelLabel`
(defaulting to the Material localizations, so they are already translated) and `isDestructive`,
which paints the confirm button in the theme's error color.

The dialog itself is `DwConfirmDialog`, a plain themed `AlertDialog`. Replace it app-wide with
`DwConfig.confirmDialogBuilder` — one setting, not a bespoke `showDialog<bool>` per call site.

Note the `(context)` at the end of the example above: this action is built and invoked on the spot,
inside a `DropdownButton.onChanged`, because there is no tappable widget to hand it to. That is
legitimate — but it means nothing is guarding the second tap.

## `DwActionBuilder`: the guard

```dart
DwActionBuilder(
  action: deleteAction,
  builder: (context, onPressed, busy) => ListTile(
    onTap: onPressed,
    trailing: busy ? const CircularProgressIndicator() : const Icon(Icons.delete),
  ),
)
```

The builder hands you exactly two things, and both matter:

- **`onPressed`** — `null` while the action runs, and `null` when `action` is `null`. Pass it
  straight through: every Material widget renders itself disabled for a `null` handler, so "disabled
  while saving" costs nothing.
- **`busy`** — the in-flight flag, for whatever the design shows: a spinner in place of the label, a
  progress indicator on an avatar, a greyed row.

While `busy` is set, a repeated tap is dropped inside the guard as well as being unreachable through
`onPressed`. This is the double-submit bug that creates two bookings, and it is fixed once here
rather than in every widget.

`DwActionBuilder` is not a button and is not for buttons only. Any tappable thing — a card, an icon,
an `InkResponse` around an avatar, a list tile — becomes action-safe by being built inside it. If
you are declaring `bool _busy` in a `StatefulWidget`, you are rewriting this widget.

### Form validation

```dart
AppButton.primary(
  l10n.continueAction,
  requireValidation: true,
  onTap: dw.action((_) async {
    await ref.read(authStateProvider.notifier).requestOtp();
  }),
)
```

With `requireValidation: true` the guard calls `Form.maybeOf(context)?.validate()` before running,
and cancels the run when it returns `false`.

With **no** enclosing `Form` the action runs anyway. That looks like the wrong default until you
consider the alternative: a guard that swallowed the tap would leave a developer staring at a button
that silently does nothing. Instead the mistake is caught where it was made — an `assert` in `build`
fires on the first frame, before anyone taps:

> `DwActionBuilder(requireValidation: true) found no enclosing Form.`

So do not set the flag "just in case". `unfocusOnTap` (on by default) drops the keyboard before the
action runs, which is nearly always what a form submit wants.

## Where errors go

A failing action does not just show a toast. `dw.handleError` captures a snapshot of the app state
at the moment of failure and dispatches a `DwErrorReport` carrying:

- `source: DwErrorSource.uiAction`;
- `actionLabel` — `label` if you set one, otherwise `onErrorNotification`, otherwise
  `onSuccessNotification`. Actions rarely get explicit labels, and a notification text names the
  action well enough for an alert title (`Action failed: changeUserRole`);
- the context snapshot: platform, app version, current route, **the ids of the `DwFeature` widgets
  mounted on the screen**, and any custom entries the app registered (`user`, `tenant`, …).

That last one is why an alert from a web build is actionable at all: the stack trace is minified
`main.js` noise, while "on `/admin/help`, features `faq-admin, admin-shell`, action
`faq.deleteQuestion`" points at a screen. See [error reporting](../2-core/error-reporting.md) for
the pipeline and [features and specs](features-and-specs.md) for where the feature ids come from.

Give an action an explicit `label` when its notification texts are generic — twelve alerts titled
"Action failed: Saved" tell you nothing.

### Unless the server refused, which is not a failure

A rule on the server that said no arrives as a **`DwRefusal`**, and the action treats it as the
answer it is: the user is shown `refusal.message` — the words the rule was written in, not the
action's `onErrorNotification` — and the framework's alerting leaves it alone. The report still
reaches a custom `DwConfig.onErrorReport`, which sorts it out by type. See
[error reporting](../2-core/error-reporting.md#a-refusal-is-not-an-error).

## Notifications

`dw.notify.success / warning / error / info` post a `DwUiNotification` from anywhere, including
outside the widget tree — no `BuildContext`, no `ScaffoldMessenger`. Rendering happens once, at the
app shell: `DwNotificationsListener` mounts an `Overlay` and routes each event by its runtime type
to a handler from its `handlers` map (`{DwUiNotification: DwUiNotificationHandler()}` is the
built-in toast). Custom types go through `dw.notify.custom(...)` and a handler of your own.

So a notification looks the same whether it came from an action, a socket event or a failed call.
Reaching for `SnackBar` directly opts one screen out of that, and nobody notices until the design
changes.
