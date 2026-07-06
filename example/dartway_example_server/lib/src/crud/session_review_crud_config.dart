import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the SessionReview model. The business rule lives in
/// [DwSaveConfig.validateSave]: a review requires your own attended booking.
final sessionReviewCrudConfig = DwCrudConfig<SessionReview>(
  table: SessionReview.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
    include: SessionReview.include(
      booking: SessionBooking.include(
        session: ClubSession.include(service: ClubService.include()),
      ),
    ),
  ),
  saveConfig: DwSaveConfig<SessionReview>(
    allowSave: (session, saveContext) async {
      final booking = await SessionBooking.db
          .findById(session, saveContext.currentModel.bookingId);
      return session.isUser(booking?.clientProfileId ?? -1);
    },
    validateSave: (session, saveContext) async {
      final review = saveContext.currentModel;
      if (review.rating < 1 || review.rating > 5) {
        return 'Rating must be between 1 and 5';
      }
      final booking =
          await SessionBooking.db.findById(session, review.bookingId);
      if (booking?.status != BookingStatus.attended) {
        return 'You can only review a session you attended';
      }
      final existingReviews = await SessionReview.db.count(
        session,
        where: (t) => t.bookingId.equals(review.bookingId),
      );
      if (saveContext.isInsert && existingReviews > 0) {
        return 'This visit is already reviewed';
      }
      return null;
    },
    beforeSaveTransaction: (session, saveContext) async {
      if (saveContext.isInsert) {
        saveContext.currentModel = saveContext.currentModel.copyWith(
          createdAt: DateTime.now(),
        );
      }
    },
  ),
);
