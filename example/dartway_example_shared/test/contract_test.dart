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
      const GetMyProfile(accountId: 42),
      const UpdateMyProfile(
        firstName: 'Vera',
        lastName: DwFieldPatch.clear(),
        gender: DwFieldPatch.set(UserGender.female),
      ),
      ListUpcomingSessions(from: DateTime.utc(2026, 9, 14)),
      const ListMyBookings(accountId: 42),
      const ListUserProfiles(page: 2, pageSize: 10, search: 'ver'),
      const ListUserProfiles(role: UserRole.staff),
      const ListChatMessages(channelId: 1),
      const SendChatMessage(channelId: 1, text: 'hi'),
      booking(id: 5, accountId: 42),
      profile(),
      const MemberCount(count: 3),
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

  test("a member's own requests live on their account's channels and take "
      'only their own objects', () {
    const bookings = ListMyBookings(accountId: 42);
    expect(bookings.channels.single.wireName, 'bookings:42');
    expect(
      bookings.onUpdate(booking(id: 1, accountId: 42)),
      DwUpdateAction.upsert,
    );
    expect(
      bookings.onUpdate(booking(id: 2, accountId: 43)),
      DwUpdateAction.remove,
      reason: "someone else's booking is never inserted",
    );
    expect(
      const GetMyProfile(accountId: 42).channels.single.wireName,
      'profile:42',
    );
  });

  test('the members table replaces its rows in place and reads its page '
      'again when the member count changes', () {
    const table = ListUserProfiles();
    expect(table.onUpdate(profile()), DwUpdateAction.update);
    expect(table.onUpdate(const MemberCount(count: 4)), DwUpdateAction.refetch);
    expect(table.onUpdate(const NewsPostCounter()), DwUpdateAction.ignore);
  });

  test('the chat window orders by the time sent, then by id', () {
    const request = ListChatMessages(channelId: 1);
    final at = DateTime.utc(2026, 9, 14, 9);
    ChatMessage message(int id, DateTime createdAt) => ChatMessage(
      id: id,
      channelId: 1,
      text: 'm$id',
      author: person,
      createdAt: createdAt,
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
          createdAt: at,
        ),
      ),
      isFalse,
    );
    expect(DwWindowCursor.decode(request.cursorOf(message(5, at))).position, (
      sortValue: at,
      id: 5,
    ));
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
