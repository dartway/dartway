import 'package:dartway_example_flutter/app/bookings/widgets/booking_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
      'Bookings are listed newest first, cancelled ones included.',
      'An active booking of a session that has not started can be cancelled.',
      'An attended visit can be reviewed once; a reviewed one says thanks.',
      'A booking made, cancelled, marked attended or reviewed — here or on '
          'another device — changes the list live.',
      'With no bookings the screen says so instead of showing an empty list.',
      'While the list loads, three placeholder cards are shown.',
      'A failed read says so and offers a retry, rather than looking like a '
          'member with no bookings.',
    ],
    requirements: [
      'A member sees only their own bookings: the request names no one, and '
          'the server reads the caller\'s.',
    ],
    implementationNotes: [
      'The review travels inside the booking, so the list is one read.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const request = ListMyBookings();

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.tabBookings)),
      body: ref
          .watch(dw.request(request))
          .section(
            loadingValue: PlaceholderObjects.listOf(
              PlaceholderObjects.booking,
              3,
            ),
            onRetry: () => ref.read(dw.request(request).notifier).refetch(),
            builder: (bookings) {
              if (bookings.isEmpty) {
                return Center(child: AppText.body(context.l10n.noBookingsYet));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    BookingCard(booking: bookings[index]),
              );
            },
          ),
    );
  }
}
