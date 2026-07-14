# Example — the other half of the feature

The server declared a `DwCrudConfig<SessionBooking>`
(see [`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server)).
Nothing else is needed: the client already has a typed, realtime-synced list of the model.

## Read: a live list

`watchModelList<T>()` returns an `AsyncValue<List<T>>` that stays in sync — when anyone writes
the model on the server, this widget rebuilds. No sockets, no manual refresh, no cache
invalidation.

```dart
class BookingsList extends ConsumerWidget {
  const BookingsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<SessionBooking>().dwBuildListAsync(
          loadingItemsCount: 4,
          childBuilder: (bookings) => ListView(
            children: [
              for (final booking in bookings) BookingCard(booking: booking),
            ],
          ),
        );
  }
}
```

`dwBuildListAsync` renders the three states of an `AsyncValue` uniformly — and the loading state
is a skeleton derived from your real widget, not a spinner.

## Filter, without writing an endpoint

Filters are declared once, as an app-side enum, and typed by the column they filter:

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();

  /// Bookings of one client. The server access filter enforces the same rule —
  /// this only narrows the query.
  static DwBackendFilter clientBookings(int userProfileId) =>
      AppBackendFilters.clientProfileId.equals(userProfileId);

  /// Schedule from the start of today onwards.
  static DwBackendFilter upcomingSessions() =>
      AppBackendFilters.startsAt.greaterThan(DateTime.now().dayStart);
}

extension on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
}
```

```dart
ref.watchModelList<SessionBooking>(
  backendFilter: AppBackendFilters.clientBookings(myProfileId),
);
```

## Write: one call, guarded by the server

```dart
AppButton.primary(
  'Book a spot',
  onTap: DwUiAction.create(
    (context) => DwRepository.saveModel(
      SessionBooking(
        clubSessionId: clubSession.id!,
        clientProfileId: myProfileId,
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      ),
    ),
    onSuccessNotification: 'You are booked',
  ),
)
```

(`AppButton` is the app's own kit widget — DartWay ships no design system; `dartway create`
scaffolds the kit into `lib/ui_kit/` as source you own. `myProfileId` is the signed-in profile:
the session service holds it, and apps usually expose it as a one-line provider — see
`lib/core/user_profile_provider.dart` in the example app.)

If the session is full, `validateSave` on the server rejects the write and its message
(`'No spots left'`) reaches the user as a notification. The rule lives in exactly one place —
the server — and the client cannot forget it. Every open list showing that booking updates
itself; nobody subscribes to anything by hand.

The full app — client, staff and admin roles over one codebase — is
[`example/`](https://github.com/dartway/dartway/tree/master/example) in the DartWay monorepo.
