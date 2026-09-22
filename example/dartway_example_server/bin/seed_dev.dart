import 'dart:io';
import 'dart:math';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/chat.dart';
import 'package:dartway_example_server/src/entities/club.dart';
import 'package:dartway_example_server/src/entities/content.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Development data: three personas who sign in with the code `111111`, a
/// price list, a week of sessions, a staff chat with weeks of history and
/// enough members to page through the admin table. Refuses to run twice.
///
/// `dart run bin/seed_dev.dart` against the database in `DW_DATABASE_*`, after
/// the server has migrated it once.
Future<void> main() async {
  final database = await DwPostgresDatabase.open(
    DwDatabaseConfig.fromEnvironment(
      DwLocalEnvironment.overlay(Platform.environment),
    ),
  );
  try {
    final db = database.db;
    if (await db.clubServices.exists()) {
      stdout.writeln('Already seeded.');
      return;
    }
    // One transaction: a seed that fails half-way leaves nothing behind.
    final chat = await db.transaction((tx) async {
      // No server runs during seeding, so nobody is subscribed: the seed's auth
      // creates the profile without publishing anything.
      final accounts = DwAccountService(
        tx,
        DwAuthConfig(
          normalize: ExampleAuth.config.normalize,
          deliverCode: ExampleAuth.config.deliverCode,
          onAccountCreated: (ctx, accountId, kind, identifier, origin) =>
              ExampleAuth.createProfile(
                ctx.db,
                accountId,
                identifier,
                const {},
              ),
        ),
      );

      Future<UserProfileRow> persona(
        String phone,
        String name,
        UserRole role, {
        String? fixedCode,
      }) async {
        final account = await accounts.ensure(DwIdentifierKind.phone, phone);
        final profile = (await tx.userProfiles.findFirst(
          where: (t) => t.accountId.equals(account.accountId),
        ))!;
        return tx.userProfiles.update(
          profile.copyWith(
            firstName: name,
            role: role,
            testVerificationCode: fixedCode == null
                ? const DwFieldPatch.keep()
                : DwFieldPatch.set(fixedCode),
          ),
        );
      }

      final admin = await persona(
        '79990000001',
        'Anna',
        UserRole.admin,
        fixedCode: '111111',
      );
      final coach = await persona(
        '79990000002',
        'Boris',
        UserRole.staff,
        fixedCode: '111111',
      );
      await persona(
        '79990000003',
        'Vera',
        UserRole.client,
        fixedCode: '111111',
      );
      final galina = await persona(
        '79990000004',
        'Galina',
        UserRole.staff,
        fixedCode: '111111',
      );
      // Members to page through: the admin table shows ten at a time.
      const names = [
        'Daria',
        'Egor',
        'Zhanna',
        'Ilya',
        'Kira',
        'Lev',
        'Maria',
        'Nikita',
        'Olga',
        'Pavel',
        'Raisa',
        'Semyon',
        'Tamara',
        'Ulyana',
        'Fedor',
      ];
      for (final (index, name) in names.indexed) {
        await persona(
          '7999100${index.toString().padLeft(4, '0')}',
          name,
          UserRole.client,
        );
      }

      final services = await tx.clubServices.insertAll([
        const ClubServiceRow(
          title: 'Yoga',
          description: 'A slow morning flow for every level.',
          durationMinutes: 60,
          price: 1200,
        ),
        const ClubServiceRow(
          title: 'Strength',
          description: 'Barbell basics in a small group.',
          durationMinutes: 50,
          price: 1500,
        ),
        const ClubServiceRow(
          title: 'Personal training',
          description: 'One coach, one client, your plan.',
          durationMinutes: 60,
          price: 3500,
        ),
      ]);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tx.clubSessions.insertAll([
        for (var day = 1; day <= 7; day++) ...[
          ClubSessionRow(
            serviceId: services[0].id!,
            coachProfileId: coach.id,
            startsAt: today.add(Duration(days: day, hours: 9)),
            capacity: 12,
          ),
          if (day.isOdd)
            ClubSessionRow(
              serviceId: services[2].id!,
              coachProfileId: coach.id,
              startsAt: today.add(Duration(days: day, hours: 12)),
              capacity: 1,
            ),
          ClubSessionRow(
            serviceId: services[1].id!,
            coachProfileId: coach.id,
            startsAt: today.add(Duration(days: day, hours: 18)),
            capacity: 8,
          ),
        ],
      ]);

      final chat = await _seedChat(tx, admin: admin, staff: [coach, galina]);
      await tx.newsPosts.insert(
        NewsPostRow(
          authorProfileId: coach.id!,
          title: 'The club is open',
          text: 'Book your first class in the schedule.',
          createdAt: now,
        ),
      );
      return chat;
    });
    stdout.writeln(
      'Seeded: admin 79990000001, staff 79990000002 and 79990000004, '
      'client 79990000003 — code 111111. Chat: ${chat.messages} messages in '
      '${chat.channels} channels; 79990000002 reopens "Front desk" '
      '$_unreadAtFrontDesk messages before its end.',
    );
  } finally {
    await database.close();
  }
}

/// Messages of "Front desk" after 79990000002's read position: the chat
/// reopens there, in the middle of its history, with these below.
const _unreadAtFrontDesk = 40;

/// Three staff channels with weeks of history: long enough to scroll back
/// through, with replies, pins, edits and reactions on the way, and read
/// positions that open one member's "Front desk" mid-history.
///
/// Every table is one `insertAll`; replies are a second one, since they need
/// the ids of the messages they quote.
Future<({int channels, int messages})> _seedChat(
  DwDatabaseHandle tx, {
  required UserProfileRow admin,
  required List<UserProfileRow> staff,
}) async {
  // Fixed: every seeded database tells the same story.
  final random = Random(20260914);
  final members = [admin, ...staff];
  final now = DateTime.now();

  final channels = await tx.chatChannels.insertAll(const [
    ChatChannelRow(title: 'Front desk'),
    ChatChannelRow(title: 'Coaches'),
    ChatChannelRow(title: 'Maintenance'),
  ]);
  final [desk, coaches, maintenance] = channels;

  /// [count] instants over the last [days], in working hours (8:00–22:00),
  /// oldest first, the newest a few minutes ago.
  List<DateTime> instants(int count, int days) {
    const workingMinutes = 14 * 60;
    final start = DateTime(now.year, now.month, now.day - days + 1, 8);
    // Today's working minutes so far, the last five left for the live chat.
    final today = ((now.hour - 8) * 60 + now.minute - 5).clamp(
      0,
      workingMinutes,
    );
    final minutesToNow = (days - 1) * workingMinutes + today;
    final offsets = [
      for (var i = 0; i < count; i++) random.nextInt(max(minutesToNow, 1)),
    ]..sort();
    return [
      for (final offset in offsets)
        DateTime(
          start.year,
          start.month,
          start.day + offset ~/ workingMinutes,
          8,
          offset % workingMinutes,
          random.nextInt(60),
        ),
    ];
  }

  String textFrom(List<String> lines) {
    final roll = random.nextInt(10);
    final first = lines[random.nextInt(lines.length)];
    if (roll < 7) return first;
    // Now and then a longer message: two or three of the lines, one after
    // another or as a list.
    final more = [
      first,
      for (var i = 0; i < 1 + roll % 2; i++)
        lines[random.nextInt(lines.length)],
    ];
    return roll == 9
        ? more.map((line) => '- $line').join('\n')
        : more.join(' ');
  }

  List<ChatMessageRow> history(
    ChatChannelRow channel,
    int count,
    int days,
    List<String> lines,
  ) => [
    for (final (index, sentAt) in instants(count, days).indexed)
      ChatMessageRow(
        channelId: channel.id!,
        authorProfileId: members[random.nextInt(members.length)].id!,
        text: textFrom(lines),
        sentAt: sentAt,
        editedAt: index % 23 == 7
            ? sentAt.add(const Duration(minutes: 3))
            : null,
      ),
  ];

  const deskReplies = 40;
  final plain = await tx.chatMessages.insertAll([
    ...history(desk, 600 - deskReplies, 21, _deskLines),
    ...history(coaches, 80, 21, _coachLines),
    ...history(maintenance, 10, 14, _maintenanceLines),
  ]);
  final deskPlain = [
    for (final row in plain)
      if (row.channelId == desk.id) row,
  ];

  final replies = <ChatMessageRow>[];
  for (var i = 0; i < deskReplies; i++) {
    final quoted = deskPlain[random.nextInt(deskPlain.length)];
    final others = [
      for (final member in members)
        if (member.id != quoted.authorProfileId) member,
    ];
    replies.add(
      ChatMessageRow(
        channelId: desk.id!,
        authorProfileId: others[random.nextInt(others.length)].id!,
        text: _replyLines[random.nextInt(_replyLines.length)],
        sentAt: _before(
          quoted.sentAt.add(Duration(minutes: 1 + random.nextInt(30))),
          now,
        ),
        replyToMessageId: quoted.id,
      ),
    );
  }
  final repliesStored = await tx.chatMessages.insertAll(replies);

  // Pins: a few notes worth keeping at the top of "Front desk".
  final pinned = <int>{};
  while (pinned.length < 5) {
    pinned.add(deskPlain[random.nextInt(deskPlain.length)].id!);
  }
  await tx.chatMessages.updateWhere(
    where: (t) => t.id.inList(pinned),
    set: (t) => [
      t.pinnedAt.set(now.subtract(const Duration(days: 1))),
      t.pinnedByProfileId.set(admin.id),
    ],
  );

  final reacted = <(int, int)>{};
  final reactions = <ChatMessageReactionRow>[];
  for (var i = 0; i < 90; i++) {
    final message = plain[random.nextInt(plain.length)];
    final member = members[random.nextInt(members.length)];
    if (!reacted.add((message.id!, member.id!))) continue;
    reactions.add(
      ChatMessageReactionRow(
        messageId: message.id!,
        profileId: member.id!,
        reaction:
            ChatReaction.values[random.nextInt(ChatReaction.values.length)],
      ),
    );
  }
  await tx.chatMessageReactions.insertAll(reactions);

  int byPosition(ChatMessageRow a, ChatMessageRow b) {
    final bySent = a.sentAt.compareTo(b.sentAt);
    return bySent != 0 ? bySent : a.id!.compareTo(b.id!);
  }

  final all = [...plain, ...repliesStored];
  List<ChatMessageRow> inOrder(ChatChannelRow channel) => [
    for (final row in all)
      if (row.channelId == channel.id) row,
  ]..sort(byPosition);
  ChatReadPositionRow position(UserProfileRow member, ChatMessageRow at) =>
      ChatReadPositionRow(
        profileId: member.id!,
        channelId: at.channelId,
        messageId: at.id!,
        sentAt: at.sentAt,
      );
  final deskInOrder = inOrder(desk);
  final [boris, galina] = staff;
  await tx.chatReadPositions.insertAll([
    // The admin has read everything.
    for (final channel in channels) position(admin, inOrder(channel).last),
    // Boris stopped mid-history in "Front desk", and is up to date elsewhere.
    position(boris, deskInOrder[deskInOrder.length - 1 - _unreadAtFrontDesk]),
    position(boris, inOrder(coaches).last),
    // Galina is a little behind at the desk and has never opened the rest.
    position(galina, deskInOrder[deskInOrder.length - 6]),
  ]);

  return (channels: channels.length, messages: all.length);
}

/// [time], unless it is past [limit]: a reply written "later" than now is
/// written a minute before it.
DateTime _before(DateTime time, DateTime limit) =>
    time.isBefore(limit) ? time : limit.subtract(const Duration(minutes: 1));

const _deskLines = [
  'Morning shift is on: doors open, towels restocked.',
  'Vera asked to move her Thursday yoga to Friday. Done.',
  'The card terminal froze again; a restart fixed it.',
  'Who has the key to the storage room?',
  'The pool closes at 20:00 today for cleaning.',
  'New member at the desk: trial week, strength group.',
  'Locker 14 is jammed. There is a note on it and maintenance knows.',
  'The coffee machine is out of milk.',
  'Two clients are waiting for personal training. Is Boris in yet?',
  'The evening strength group is full; new names go on the waiting list.',
  'The screen by the entrance still shows last month\'s prices.',
  'New mats arrive tomorrow between 10 and 12, someone has to sign for them.',
  'Lost and found: a blue water bottle and a pair of gloves.',
  'A refund for a cancelled personal session is waiting for approval.',
  'Printed new schedules and put them on the stand.',
  'A client complained that the showers on the left are cold again.',
  'Wi-Fi password for guests changed, the new one is on the card at the desk.',
  'Three bookings moved from Monday to Wednesday at the coach\'s request.',
  'Closing now: lights off in the hall, alarm set.',
  'Someone left a car with its lights on, silver hatchback, plate ends in 17.',
  'The yoga room smells of paint, open the windows before the class.',
  'Please remind clients that the sauna is booked by the hour.',
  'Gift cards are almost out, we have five left.',
  'The courier with the protein bars is here, where do we put the boxes?',
  'A school group asked about a discount for 12 people, sent them the '
      'price list.',
];

const _replyLines = [
  'On it.',
  'Thanks, noted.',
  'Done.',
  'I will take care of it after lunch.',
  'Already sorted this morning.',
  'Can you send a photo?',
  'Good catch, thank you!',
  'Let us discuss at the handover.',
  'I have told the client.',
  'Not yet, waiting for a call back.',
];

const _coachLines = [
  'Swapping my 18:00 group with Galina on Friday, agreed.',
  'The barbells in hall 2 need new collars.',
  'Anyone free to cover the Sunday morning yoga?',
  'New warm-up plan for the beginners is in the shared folder.',
  'Two clients asked for a nutrition consultation, who does those now?',
  'The kettlebells from 16 kg up are all in hall 1 today.',
  'Reminder: first aid refresher on the 25th, 10:00.',
  'My personal client moved to 12:00, the hall is free at 11.',
  'The music speaker in the yoga room keeps disconnecting.',
  'Great turnout at strength today, 8 of 8.',
];

const _maintenanceLines = [
  'The treadmill in the corner makes a knocking sound at high speed.',
  'Left shower drain is slow again.',
  'Replaced two lamps in the corridor.',
  'Air conditioning in hall 2 serviced, filters changed.',
  'The front door closer needs adjusting, it slams.',
];
