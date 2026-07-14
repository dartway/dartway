# Example — bootstrap, guarded actions, notifications

## Start the app

`DwAppRunner` owns what every app sets up and no app enjoys setting up: the `ProviderScope`,
the native splash, async initializers, and a zone that catches what would otherwise be lost.

```dart
void main() {
  DwAppRunner(
    appInitializers: [initFirebase, loadAppSettings],
    child: const MyMaterialApp(),
  ).run();
}
```

## Describe an action, don't orchestrate it

`DwUiAction` says *what* happens; the framework handles the rest — the in-flight flag, the
re-entrancy guard (a double tap does not book twice), optional `Form` validation, the success
notification and the error report.

```dart
AppButton.primary(
  'Book a spot',
  onTap: DwUiAction.create(
    // any Future<void>; with the DartWay data layer this is
    // `DwRepository.saveModel(booking)` — this package stays data-layer agnostic
    (context) => bookSpot(booking),
    onSuccessNotification: 'You are booked',
  ),
)
```

Destructive actions get a confirmation without an `if` in your widget:

```dart
DwUiAction.create(
  (context) => cancelBooking(booking),
  confirmation: const DwUiConfirmation(
    'Your spot will be given away.',
    title: 'Cancel the booking?',
    confirmLabel: 'Cancel booking',
    isDestructive: true,
  ),
  onSuccessNotification: 'Booking cancelled',
)
```

## The same guard under any widget

The mechanism is not welded to a button. `DwActionBuilder` binds an action to anything tappable
and hands you the `busy` flag:

```dart
DwActionBuilder(
  action: deleteAction,
  builder: (context, onPressed, busy) => ListTile(
    onTap: onPressed,
    title: const Text('Delete'),
    trailing: busy
        ? const CircularProgressIndicator()
        : const Icon(Icons.delete),
  ),
)
```

## Notify from anywhere

```dart
dw.notify.success('Profile saved');
dw.notify.error('Could not reach the server');
```

(`dw` is the core instance the app declares once at startup — the package exports no global.)

## No design system, on purpose

There is no `DwButton` here — `AppButton` above is *your* widget, scaffolded into your
`lib/ui_kit/` by `dartway create` as source you own. This package ships the mechanism, not the
corner radius.

The canonical usage is [`example/`](https://github.com/dartway/dartway/tree/master/example) in
the DartWay monorepo — a full service-business app, including the UI kit you get from the CLI.
