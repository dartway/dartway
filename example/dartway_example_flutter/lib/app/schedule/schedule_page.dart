import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_app_bar.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_session_list.dart';
import 'package:dartway_example_flutter/core/router/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class SchedulePage extends StatelessWidget implements DwFeatureWidget {
  const SchedulePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'schedule/sessions',
    title: 'Schedule',
    purpose:
        'A club member sees what is on in the coming days and books a place '
        'without leaving the list.',
    behaviors: [
      'Sessions from the start of today on are grouped by day, nearest first.',
      'Each card shows the spots left, and they change live as anyone books '
          'or cancels.',
      'Booking or cancelling flips the card without a manual refresh.',
      'A full session cannot be booked; one that has started offers nothing.',
      'While the reads load, five placeholder cards are shown.',
      'A failed read says so and offers a retry, rather than looking like a '
          'week with nothing on.',
    ],
    requirements: [
      'A member sees only their own bookings on the cards — the server '
          'refuses anyone else\'s.',
      'Booking rules (capacity, a started session, a second booking) are the '
          'server\'s: a refused booking shows why.',
    ],
    implementationNotes: [
      'The list waits for both reads. A card drawn before your bookings arrive '
          'would offer "Book" on a session you already hold.',
      'The day the list starts from is one stable value per day, because a '
          'request is its own cache key.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return const AppScaffold.main(
      appBar: ScheduleAppBar(),
      body: ScheduleSessionList(),
    );
  }
}
