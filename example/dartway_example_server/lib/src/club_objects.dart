import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../generated/dw_schema.dart';
import 'entities/club.dart';
import 'entities/content.dart';
import 'entities/people.dart';

/// Rows → the data objects clients see. Related rows are loaded in one query
/// per relation for the whole batch, never per row, and not at all when the
/// caller already holds them.
abstract final class ClubObjects {
  static PersonCard person(UserProfileRow row) => PersonCard(
    id: row.id!,
    firstName: row.firstName,
    lastName: row.lastName,
    imageUrl: row.imageUrl,
    isDeleted: row.deletedAt != null,
  );

  static UserProfile profile(UserProfileRow row) => UserProfile(
    id: row.id!,
    accountId: row.accountId,
    phone: row.phone,
    firstName: row.firstName,
    lastName: row.lastName,
    imageUrl: row.imageUrl,
    gender: row.gender,
    role: row.role,
    agreedForMarketing: row.agreedForMarketing,
    isDeleted: row.deletedAt != null,
  );

  static ClubService service(ClubServiceRow row) => ClubService(
    id: row.id!,
    title: row.title,
    description: row.description,
    durationMinutes: row.durationMinutes,
    price: row.price,
    imageUrl: row.imageUrl,
  );

  static Future<Map<int, UserProfileRow>> _profiles(
    DwDatabaseHandle db,
    Iterable<int?> ids,
  ) async {
    final wanted = ids.whereType<int>().toSet();
    if (wanted.isEmpty) return const {};
    return {
      for (final row in await db.userProfiles.findByIds(wanted)) row.id!: row,
    };
  }

  static Future<List<ClubSession>> sessions(
    DwDatabaseHandle db,
    List<ClubSessionRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final services = {
      for (final row in await db.clubServices.findByIds(
        rows.map((s) => s.serviceId).toSet(),
      ))
        row.id!: service(row),
    };
    final coaches = await _profiles(db, rows.map((s) => s.coachProfileId));
    return [
      for (final row in rows)
        ClubSession(
          id: row.id!,
          service: services[row.serviceId]!,
          coach: switch (coaches[row.coachProfileId]) {
            final coach? => person(coach),
            null => null,
          },
          startsAt: row.startsAt,
          capacity: row.capacity,
          bookedCount: row.bookedCount,
        ),
    ];
  }

  /// [client] is the profile every row belongs to, when the caller holds it;
  /// [session] the data object of every row's session, likewise.
  static Future<List<SessionBooking>> bookings(
    DwDatabaseHandle db,
    List<SessionBookingRow> rows, {
    UserProfileRow? client,
    ClubSession? session,
  }) async {
    if (rows.isEmpty) return const [];
    final sessionsById = session != null
        ? {session.id: session}
        : {
            for (final s in await sessions(
              db,
              await db.clubSessions.findByIds(
                rows.map((b) => b.sessionId).toSet(),
              ),
            ))
              s.id: s,
          };
    final clients = client != null
        ? {client.id!: client}
        : await _profiles(db, rows.map((b) => b.clientProfileId));
    // Only an attended visit can have been reviewed.
    final attended = [
      for (final row in rows)
        if (row.status == BookingStatus.attended) row.id!,
    ];
    final reviews = attended.isEmpty
        ? const <int, SessionReview>{}
        : {
            for (final r in await db.sessionReviews.find(
              where: (t) => t.bookingId.inList(attended),
            ))
              r.bookingId: SessionReview(
                id: r.id!,
                rating: r.rating,
                text: r.text,
                createdAt: r.createdAt,
              ),
          };
    return [
      for (final row in rows)
        SessionBooking(
          id: row.id!,
          // A booking always belongs to someone who is here: the last thing
          // a member's deletion does is cancel the ones still ahead, and the
          // ones behind are read by nobody but them.
          accountId: clients[row.clientProfileId]!.ownerAccountId,
          session: sessionsById[row.sessionId]!,
          status: row.status,
          createdAt: row.createdAt,
          review: reviews[row.id],
        ),
    ];
  }

  /// [author] is the author of every post, when the caller holds it.
  static Future<List<NewsPost>> news(
    DwDatabaseHandle db,
    List<NewsPostRow> rows, {
    UserProfileRow? author,
  }) async {
    final authors = author != null
        ? {author.id!: author}
        : await _profiles(db, rows.map((p) => p.authorProfileId));
    return [
      for (final row in rows)
        NewsPost(
          id: row.id!,
          title: row.title,
          text: row.text,
          author: person(authors[row.authorProfileId]!),
          createdAt: row.createdAt,
        ),
    ];
  }
}
