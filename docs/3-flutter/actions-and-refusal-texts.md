# What happens when the user taps, and how does a "no" reach them?

Every user action repeats the same steps: ask for confirmation if it is destructive, send the
command, tell the user it worked, do the follow-up — or, when it did not work, say why in words the
user understands and report what an operator must see. Written by hand, those steps are copied into
every widget, and each copy forgets a different one.

DartWay splits the problem in two, and adds one project file:

- **`DwUiAction` — what the action does.** Confirmation, the call, notifications, follow-up, and what
  a refused or failed result means. Built with `dw.action(...)`.
- **`DwActionBuilder` — what the UI does while it runs.** The in-flight flag, the dropped second tap,
  form validation, focus.
- **`lib/core/refusal_text.dart` — what a refusal says.** The project's mapping from refusal codes to
  localized sentences, handed to `DwConfig.refusalText`.

The framework ships no button. It ships the mechanisms a button would otherwise have to contain.

## `dw.action` returns a value, not a callback

```dart
// example/dartway_example_flutter/lib/app/schedule/widgets/session_card.dart
AppButton.primary(
  l10n.book,
  onTap: dw.action(
    (_) => dw.command(BookSession(sessionId: session.id)),
    onSuccessNotification: l10n.youAreBooked,
  ),
)
```

`dw.action(...)` is a `DwUiAction<T>` — **not** a `VoidCallback`, and the compiler says so if you hand
it to `onPressed:`. Two reasons:

- **it needs a `BuildContext`.** The confirmation dialog, the follow-up and any navigation need the
  tree. An action is invoked as `action(context)`, and the callback you write receives the context
  too (`(_)` when you do not need it).
- **it does not know whether it is running.** "In flight" belongs to the widget that was tapped, not to
  a value you store and pass around — which is what lets one action sit behind a button on one screen
  and a list tile on another.

`DwUiAction` has no public constructor: its work is woven into the ambient services (`dw.confirm`,
`dw.notify`, `dw.handleError`), so its factory lives on `dw`.

## What `dw.action` does, in order

1. **Confirmation.** With `confirmation:` set, the dialog is shown first. Anything but `true` —
   declined, dismissed, the context gone — stops here: no call, no notifications, no follow-up, and the
   action returns `null`.
2. **Your callback**, awaited.
3. **A result is understood.** When the callback returns a `DwCallResult` — as
   `(_) => dw.command(...)` does — only `DwCallOk` is success. Any other result is treated as the
   exception it stands for, and handled below. You never unwrap a result to get the refusal shown.
4. **`onSuccessNotification`**, through `dw.notify.success`.
5. **`customNotificationBuilder(value)`** — a notification derived from the result; `null` posts
   nothing.
6. **`followUpIfMountedAction(context, value)`** — close a sheet, navigate. Skipped when the context is
   gone, the check a hand-written handler forgets.

When the callback throws or the result is not a success, steps 4–6 do not run, and the action returns
`null` rather than rethrowing — a failed action never crashes the screen. What it does instead depends
on what went wrong:

| What went wrong | What the user sees | What else |
|---|---|---|
| A refusal — `DwCallRefused`, or a `DwRefusalException` thrown by your own code | `DwConfig.refusalText(refusal)` as an error notification. It wins over `onErrorNotification`, which was written once for every way the action could fail. | — |
| A refusal that is an incompatibility (`dw.updateRequired`, `dw.protocolUnsupported`) while `updateRequiredScreen` is set | nothing: the update page over the app is already the message | — |
| Not authenticated — `DwNotAuthenticated`, or `DwNotAuthenticatedException` | nothing: the sign-in screen is the message | `dw.signOut()` |
| Anything else — `DwCallFailed`, a `DwTimeoutException`, a bug | `onErrorNotification`, when set | — |

In **every** case `onError(error, stackTrace)` is called when given, and the error goes to
`dw.handleError` with `DwErrorSource.uiAction` and an `actionLabel` — `label`, else
`onErrorNotification`, else `onSuccessNotification`. The app's error policy sees everything and sorts
it by type; see [error reporting](error-reporting.md). The skeleton's policy ignores refusals and
not-authenticated answers, and shows a generic "it did not work" notification for any other failure of
a `uiAction` — so a command that timed out never ends in silence.

`packages/dartway_core_flutter/test/dw_flutter_core_test.dart` proves the first and third rows: a
refused command shows the catalogue's text with no follow-up, and a not-authenticated answer signs out
with no notification.

## Confirmation

```dart
// example/dartway_example_flutter/lib/admin/users/widgets/admin_users_table.dart
dw.action(
  (_) => dw.command(ChangeRole(profileId: user.id, role: role)),
  label: 'changeUserRole',
  confirmation: DwUiConfirmation(
    context.l10n.confirmChangeRole(displayName, context.l10n.roleName(role.name)),
  ),
)(context);
```

`DwUiConfirmation` is declarative: `message`, optional `title`, `confirmLabel` / `cancelLabel`
(defaulting to Material's localized OK and Cancel) and `isDestructive`, which paints the confirm button
in the theme's error colour. The built-in dialog is `DwConfirmDialog`; replace it app-wide with
`DwConfig.confirmDialogBuilder`.

Note the `(context)` at the end: this action is built and run on the spot inside a
`DropdownButton.onChanged`, because there is no tappable widget to hand it to. Legitimate — but nothing
guards a second tap.

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

- **`onPressed`** is `null` while the action runs and when `action` is `null`. Pass it straight
  through: a Material widget renders itself disabled for a `null` handler.
- **`busy`** is the in-flight flag, for a spinner in place of a label or a progress ring on an avatar.

While `busy`, a repeated tap is dropped — the double submit that books a session twice is fixed once,
here. `DwActionBuilder` is not only for buttons: a card, an `InkResponse` around an avatar, a list tile
becomes action-safe by being built inside it. A `bool _busy` in a `StatefulWidget` is this widget
rewritten. The app's kit button wraps it (`lib/ui_kit/theme/app_button.dart`); see [the UI kit](ui-kit.md).

### Form validation

```dart
// template/dartway_starter_flutter/lib/auth/profile_name_page.dart
AppButton.primary(
  l10n.continueAction,
  requireValidation: true,
  onTap: dw.action(
    (_) => dw.command(UpdateMyProfile(firstName: name.value.trim())),
  ),
)
```

With `requireValidation: true` the guard runs the enclosing `Form`'s validators before the action,
and cancels the run when they fail. With **no** enclosing `Form` the action runs anyway — a guard that
swallowed the tap would leave a dead button — and an `assert` fires in `build`, before the first tap:
`DwActionBuilder(requireValidation: true) found no enclosing Form.` `unfocusOnTap` (on by default)
drops the keyboard first.

**Two layers of validation, and the framework joins neither to the other.** The `Form`'s validators
are widget code: instant feedback under a field. A DTO that is `DwSelfValidating` validates itself in
the client before it is sent — a command that does not validate answers its **first** refusal at once,
without a round trip, and the server runs the same `validate()` again. That refusal reaches the user as
any refusal does: a notification rendered by `refusalText`. It carries `field`, which the catalogue can
read to phrase it; the framework does not route it to a form field.

## Refusal texts: the project's catalogue

A `DwCallRefusal` is **a code with parameters, never a sentence**: `code` (`noSpotsLeft`,
`dw.notFound`), `params` (strings on the wire: `{'attemptsLeft': '2'}`) and an optional `field`. The server does not know
the user's language; the app does. So the words live in the app, in one function
(`template/dartway_starter_flutter/lib/core/refusal_text.dart`):

```dart
final Map<String, DwRefusalCode> _codes = {
  for (final code in <DwRefusalCode>[
    ...DartwayStarterRefusal.values,
    ...DwCoreRefusal.values,
    ...DwAuthRefusal.values,
    ...DwUploadRefusal.values,
  ])
    code.code: code,
};

String refusalText(AppLocalizations l10n, DwCallRefusal refusal) =>
    switch (_codes[refusal.code]) {
      final DartwayStarterRefusal code => _appText(l10n, code),
      final DwCoreRefusal code => _coreText(l10n, code, refusal),
      final DwAuthRefusal code => _authText(l10n, code),
      final DwUploadRefusal code => _uploadText(l10n, code, refusal),
      _ => l10n.refusalGeneric,
    };
```

and wires it once, in `dw_core.dart`:

```dart
refusalText: (refusal) => refusalText(appL10n, refusal),
```

What this shape buys:

- **every code has a sentence, checked by the compiler.** Each `_…Text` is an exhaustive `switch` over
  its enum — the project's `<Project>Refusal` (an enum `with DwRefusalCodes`) and the framework's
  `DwCoreRefusal`, `DwAuthRefusal`, `DwUploadRefusal`. A code added on either side does not compile
  until it has a text;
- **a code nobody knows still reads as a sentence.** A newer server can send a code this build has
  never seen; it gets `refusalGeneric` instead of a raw code;
- **parameters and the field shape the words.** `DwCoreRefusal.invalid` is phrased by `refusal.field`;
  `tooManyRequests` reads `refusal.retryAfter`; a wrong code reads `params['attemptsLeft']`; an
  oversized upload reads `params['maxBytes']`;
- **it is testable without a widget.** `template/dartway_starter_flutter/test/core/refusal_text_test.dart`
  asserts, for every supported locale, that no known code falls back to the generic text, and that
  parameters are used.

`refusalText` is a plain function of `AppLocalizations`, so a screen that renders a refusal itself —
under an avatar, beside a field — calls the same function (`refusalText(l10n, refusal)`) rather than
inventing a second wording. What codes exist and what each means on the server is
[refusals and statuses](../2-core/refusals-and-statuses.md).

## Notifications

`dw.notify.success / info / warning / error(message)` post a `DwUiNotification` from anywhere —
including outside the widget tree, with no `BuildContext` and no `ScaffoldMessenger`.
`dw.notify.custom(value)` posts a value of your own type.

They are rendered once, at the app shell. From `example/dartway_example_flutter/lib/dartway_example_app.dart`:

```dart
builder: (context, child) => DwNotificationsListener(
  handlers: {DwUiNotification: DwUiNotificationHandler()},
  child: SignedInGate(child: child ?? const SizedBox.shrink()),
),
```

`DwNotificationsListener` mounts an `Overlay` and routes each notification by its runtime type to a
handler; `DwUiNotificationHandler` is the built-in toast, and a custom type needs a
`DwNotificationHandler` of your own. A notification posted before any listener is mounted is dropped,
with a debug-mode warning. So a notification looks the same whether it came from an action, a live
update or a failed upload; reaching for `SnackBar` directly opts one screen out of that.

## Related

- [The data layer](data-layer.md) — `dw.command` and `DwCallResult`.
- [Refusals and statuses](../2-core/refusals-and-statuses.md) — where refusals come from.
- [Error reporting](error-reporting.md) — where failed actions go.
- The `dartway-data-layer` skill — commands, actions and refusal texts inside a project.
