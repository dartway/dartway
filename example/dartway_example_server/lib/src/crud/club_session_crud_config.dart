import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the ClubSession model (schedule entries).
/// Anyone signed in can browse the schedule; staff manages it.
final clubSessionCrudConfig = DwCrudConfig<ClubSession>(
  table: ClubSession.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
    include: ClubSession.include(
      service: ClubService.include(),
      coachProfile: UserProfile.include(),
    ),
    defaultOrderByList: [
      Order(column: ClubSession.t.startsAt, orderDescending: false),
    ],
  ),
  saveConfig: DwSaveConfig<ClubSession>(
    allowSave: (session, saveContext) async => session.isStaffMember,
    validateSave: (session, saveContext) async {
      final clubSession = saveContext.currentModel;
      if (clubSession.capacity < 1) {
        return 'Capacity must be at least 1';
      }
      if (saveContext.isInsert &&
          clubSession.startsAt.isBefore(DateTime.now())) {
        return 'Session cannot start in the past';
      }
      return null;
    },
  ),
  deleteConfig: DwDeleteConfig<ClubSession>(
    allowDelete: (session, model) => session.isStaffMember,
  ),
);
