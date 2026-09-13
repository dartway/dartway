import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';

import '../generated/dw_schema.dart';
import 'entities/club.dart';
import 'entities/content.dart';
import 'entities/people.dart';

/// Entity → view mappings. Related rows are loaded in one query per relation
/// for the whole batch, never per row.
abstract final class Views {
  static PersonView person(UserProfile p) => PersonView(
    id: p.id!,
    firstName: p.firstName,
    lastName: p.lastName,
    imageUrl: p.imageUrl,
  );

  static ProfileView profile(UserProfile p) => ProfileView(
    id: p.id!,
    phone: p.phone,
    firstName: p.firstName,
    lastName: p.lastName,
    imageUrl: p.imageUrl,
    gender: p.gender,
    role: p.role,
    agreedForMarketing: p.agreedForMarketing,
  );

  static ClubServiceView service(ClubService s) => ClubServiceView(
    id: s.id!,
    title: s.title,
    description: s.description,
    durationMinutes: s.durationMinutes,
    price: s.price,
    imageUrl: s.imageUrl,
  );

  static Future<Map<int, PersonView>> people(DwDb db, Iterable<int?> ids) async {
    final wanted = ids.whereType<int>().toSet();
    if (wanted.isEmpty) return const {};
    return {
      for (final p in await db.userProfiles.findByIds(wanted.toList()))
        p.id!: person(p),
    };
  }

  static Future<List<ClubSessionView>> sessions(
    DwDb db,
    List<ClubSession> sessions,
  ) async {
    if (sessions.isEmpty) return const [];
    final services = {
      for (final s in await db.clubServices.findByIds(
        sessions.map((s) => s.serviceId).toSet().toList(),
      ))
        s.id!: service(s),
    };
    final coaches = await people(db, sessions.map((s) => s.coachProfileId));
    return [
      for (final s in sessions)
        ClubSessionView(
          id: s.id!,
          service: services[s.serviceId]!,
          coach: coaches[s.coachProfileId],
          startsAt: s.startsAt,
          capacity: s.capacity,
          bookedCount: s.bookedCount,
        ),
    ];
  }

  static Future<ClubSessionView> session(DwDb db, ClubSession s) async =>
      (await sessions(db, [s])).single;

  static Future<List<BookingView>> bookings(
    DwDb db,
    List<SessionBooking> bookings,
  ) async {
    if (bookings.isEmpty) return const [];
    final sessionRows = await db.clubSessions.findByIds(
      bookings.map((b) => b.sessionId).toSet().toList(),
    );
    final sessionViews = {
      for (final v in await sessions(db, sessionRows)) v.id: v,
    };
    final bookingIds = bookings.map((b) => b.id!).toList();
    final reviews = {
      for (final r in await db.sessionReviews.find(
        where: (t) => t.bookingId.inList(bookingIds),
      ))
        r.bookingId: ReviewView(
          id: r.id!,
          rating: r.rating,
          text: r.text,
          createdAt: r.createdAt,
        ),
    };
    return [
      for (final b in bookings)
        BookingView(
          id: b.id!,
          session: sessionViews[b.sessionId]!,
          status: b.status,
          createdAt: b.createdAt,
          review: reviews[b.id],
        ),
    ];
  }

  static Future<BookingView> booking(DwDb db, SessionBooking b) async =>
      (await bookings(db, [b])).single;

  static Future<List<NewsPostView>> news(DwDb db, List<NewsPost> posts) async {
    final authors = await people(db, posts.map((p) => p.authorProfileId));
    return [
      for (final p in posts)
        NewsPostView(
          id: p.id!,
          title: p.title,
          text: p.text,
          author: authors[p.authorProfileId]!,
          createdAt: p.createdAt,
        ),
    ];
  }

  static Future<List<ChatMessageView>> messages(
    DwDb db,
    List<ChatMessage> messages,
  ) async {
    final authors = await people(db, messages.map((m) => m.authorProfileId));
    return [
      for (final m in messages)
        ChatMessageView(
          id: m.id!,
          channelId: m.channelId,
          text: m.text,
          author: authors[m.authorProfileId]!,
          createdAt: m.createdAt,
        ),
    ];
  }
}
