import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

const person = PersonCard(id: 2, firstName: 'Boris');
const yoga = ClubService(
  id: 1,
  title: 'Yoga',
  description: 'Flow',
  durationMinutes: 60,
  price: 1200,
);

UserProfile profile({int id = 7, int accountId = 42, UserRole? role}) =>
    UserProfile(
      id: id,
      accountId: accountId,
      phone: '79990000003',
      firstName: 'Vera',
      role: role ?? UserRole.client,
      agreedForMarketing: false,
    );

SessionBooking booking({required int id, required int accountId}) =>
    SessionBooking(
      id: id,
      accountId: accountId,
      session: ClubSession(
        id: 11,
        service: yoga,
        startsAt: DateTime.utc(2026, 9, 15, 9),
        capacity: 12,
        bookedCount: 3,
        coach: person,
      ),
      status: BookingStatus.booked,
      createdAt: DateTime.utc(2026, 9, 14),
    );

void main() {
  test('every data object, request and command travels and comes back '
      'equal', () {
    final calls = <DwWireObject>[
      const GetMyProfile(),
      const UpdateMyProfile(
        firstName: 'Vera',
        lastName: DwFieldPatch.clear(),
        gender: DwFieldPatch.set(UserGender.female),
      ),
      ListUpcomingSessions(from: DateTime.utc(2026, 9, 14)),
      const ListMyBookings(),
      const ListUserProfiles(page: 2, pageSize: 10, search: 'ver'),
      const ListUserProfiles(role: UserRole.staff),
      const ListChatMessages(channelId: 1),
      const SendChatMessage(channelId: 1, text: 'hi'),
      const SendChatMessage(
        channelId: 1,
        text: '',
        replyToMessageId: 4,
        attachments: [ChatAttachmentDraft(id: 9, width: 640, height: 480)],
      ),
      const EditChatMessage(messageId: 4, text: 'fixed'),
      const DeleteChatMessage(messageId: 4),
      const PinChatMessage(messageId: 4, pinned: true),
      const ReactToChatMessage(messageId: 4, reaction: ChatReaction.fire),
      const ReactToChatMessage(messageId: 4),
      const MarkChatRead(channelId: 1, messageId: 4),
      const ListPinnedChatMessages(channelId: 1),
      const SearchChatMessages(channelId: 1, query: 'yoga'),
      const ListMyChatReadStates(),
      ChatReadState(
        id: 1,
        unreadCount: 3,
        lastReadMessageId: 4,
        lastReadSentAt: DateTime.utc(2026, 9, 14, 9),
      ),
      ChatMessage(
        id: 5,
        channelId: 1,
        text: 'see above',
        author: person,
        sentAt: DateTime.utc(2026, 9, 14, 10),
        editedAt: DateTime.utc(2026, 9, 14, 11),
        pinnedAt: DateTime.utc(2026, 9, 14, 12),
        replyTo: ChatMessageQuote(
          id: 4,
          sentAt: DateTime.utc(2026, 9, 14, 9),
          authorName: 'Boris',
          text: '',
          isDeleted: true,
        ),
        attachments: const [
          ChatAttachment(
            id: 9,
            fileName: 'plan.png',
            contentType: 'image/png',
            byteSize: 2048,
            width: 640,
            height: 480,
          ),
        ],
        reactions: const [
          ChatMessageReaction(id: 2, reaction: ChatReaction.heart),
        ],
      ),
      booking(id: 5, accountId: 42),
      profile(),
      const AdminCounters(members: 3, upcomingSessions: 2, newsPosts: 1),
    ];
    for (final call in calls) {
      expect(
        dartwayExampleProtocol.decodeNamed(call.dwTypeName, call.toJson()),
        call,
        reason: call.dwTypeName,
      );
    }
  });

  test('commands check the fields they carry, on either side', () {
    List<String> codes(DwSelfValidating dto) => [
      for (final refusal in dto.validate()) '${refusal.code}@${refusal.field}',
    ];
    expect(codes(const UpdateMyProfile(firstName: '  ')), [
      'firstNameRequired@firstName',
    ]);
    expect(codes(const UpdateMyProfile()), isEmpty);
    expect(codes(const ReviewVisit(bookingId: 1, rating: 0)), [
      'ratingOutOfRange@rating',
    ]);
    expect(codes(const PublishNews(title: '', text: ' ')), [
      'titleRequired@title',
      'textRequired@text',
    ]);
    expect(codes(const SendChatMessage(channelId: 1, text: '\n')), [
      'messageEmpty@text',
    ]);
    expect(
      codes(
        const SendChatMessage(
          channelId: 1,
          text: ' ',
          attachments: [ChatAttachmentDraft(id: 1)],
        ),
      ),
      isEmpty,
      reason: 'a picture needs no words',
    );
    expect(
      codes(
        SendChatMessage(
          channelId: 1,
          text: 'x' * (ChatMessage.maxTextLength + 1),
          attachments: [
            for (var id = 0; id <= ChatMessage.maxAttachments; id++)
              ChatAttachmentDraft(id: id),
          ],
        ),
      ),
      ['messageTooLong@text', 'tooManyAttachments@attachments'],
    );
    expect(codes(const SearchChatMessages(channelId: 1, query: ' a ')), [
      'searchQueryTooShort@query',
    ]);
    expect(codes(const SaveAppSetting(key: 'colour', value: 'red')), [
      'settingKeyUnknown@key',
    ]);
    expect(
      codes(
        ScheduleSession(
          serviceId: 1,
          startsAt: DateTime.utc(2026, 9, 15),
          capacity: 0,
        ),
      ),
      ['capacityTooSmall@capacity'],
    );
  });

  test("a member's own requests name no account: they live on the caller's "
      'channels, resolved for whoever is signed in', () {
    const bookings = ListMyBookings();
    expect(
      bookings.channels.single,
      const DwLiveChannel.ofCaller(ExampleChannel.bookings),
    );
    expect(bookings.channels.single.resolvedFor(42).wireName, 'bookings:42');
    expect(
      bookings.onUpdate(booking(id: 1, accountId: 42)),
      DwUpdateAction.upsert,
    );
    expect(
      const GetMyProfile().channels.single.resolvedFor(42).wireName,
      'profile:42',
    );
  });

  test('the members table upserts matching profiles — in place on the page, '
      'a read of the page otherwise — and a profile leaving its filter is '
      'removed', () {
    const table = ListUserProfiles();
    expect(table.onUpdate(profile()), DwUpdateAction.upsert);
    expect(table.onUpdate(const NewsPostCounter()), DwUpdateAction.ignore);

    const staff = ListUserProfiles(role: UserRole.staff, search: ' VER ');
    expect(
      staff.onUpdate(profile(role: UserRole.staff)),
      DwUpdateAction.upsert,
    );
    expect(staff.onUpdate(profile()), DwUpdateAction.remove);
    expect(
      const ListUserProfiles(search: '0000').onUpdate(profile()),
      DwUpdateAction.upsert,
      reason: 'by phone',
    );
    expect(
      const ListUserProfiles(search: 'oleg').onUpdate(profile()),
      DwUpdateAction.remove,
    );
  });

  test('the chat window orders by the time sent, then by id', () {
    const request = ListChatMessages(channelId: 1);
    final at = DateTime.utc(2026, 9, 14, 9);
    ChatMessage message(int id, DateTime sentAt) => ChatMessage(
      id: id,
      channelId: 1,
      text: 'm$id',
      author: person,
      sentAt: sentAt,
    );
    expect(
      request.compareItems(message(2, at), message(1, at)),
      greaterThan(0),
    );
    expect(
      request.compareItems(
        message(1, at.add(const Duration(microseconds: 1))),
        message(2, at),
      ),
      greaterThan(0),
    );
    expect(request.matches(message(1, at)), isTrue);
    expect(
      request.matches(
        ChatMessage(
          id: 3,
          channelId: 2,
          text: 'elsewhere',
          author: person,
          sentAt: at,
        ),
      ),
      isFalse,
    );
    expect(DwWindowCursor.decode(request.cursorOf(message(5, at))).position, (
      sortValue: at,
      id: 5,
    ));
  });

  test('the read position reopens the window at the message it names', () {
    final at = DateTime.utc(2026, 9, 14, 9);
    expect(const ChatReadState(id: 1, unreadCount: 0).lastReadCursor, isNull);
    final read = ChatReadState(
      id: 1,
      unreadCount: 2,
      lastReadMessageId: 7,
      lastReadSentAt: at,
    );
    expect(DwWindowCursor.decode(read.lastReadCursor!).position, (
      sortValue: at,
      id: 7,
    ));
    expect(
      const ListMyChatReadStates().channels.single.resolvedFor(42).wireName,
      'chatReads:42',
    );
  });

  test('the pinned list hears a pin and an unpin anywhere in the channel, '
      'newest first', () {
    const pinned = ListPinnedChatMessages(channelId: 1);
    final at = DateTime.utc(2026, 9, 14, 9);
    ChatMessage message(int id, {DateTime? pinnedAt, int channelId = 1}) =>
        ChatMessage(
          id: id,
          channelId: channelId,
          text: 'm$id',
          author: person,
          sentAt: at.add(Duration(minutes: id)),
          pinnedAt: pinnedAt,
        );
    expect(pinned.onUpdate(message(1, pinnedAt: at)), DwUpdateAction.upsert);
    expect(pinned.onUpdate(message(1)), DwUpdateAction.remove);
    expect(
      pinned.onUpdate(message(1, pinnedAt: at, channelId: 2)),
      DwUpdateAction.remove,
    );
    expect(pinned.sort(message(2), message(1)), lessThan(0));
  });
}

/// A data object no example request declares.
final class NewsPostCounter extends DwDataObject {
  const NewsPostCounter();

  @override
  String get id => 'x';

  @override
  String get dwTypeName => 'NewsPostCounter';

  @override
  Map<String, Object?> toJson() => const {};
}
