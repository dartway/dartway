// ignore_for_file: invalid_use_of_internal_member

import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/crud/dw_auth_verification_config.dart';
import 'package:serverpod/serverpod.dart';

import '../business/auth/dw_auth.dart';
import '../business/cloud_storage/dw_cloud_storage.dart';
import '../crud/dw_auth_key_config.dart';
import '../crud/dw_auth_request_config.dart';
import '../domain/crud/domain/dw_crud_entity.dart';
import '../endpoints/dw_real_time_endpoint.dart';
import '../private/dw_singleton.dart';
import '../utils/iterable_extension.dart';

// TODO: add documentation
/// The core class for the DartWay framework.
///
/// This class is responsible for initializing the framework and providing access to the core functionality.
///
/// It contains the main components of the framework:
/// - [userProfileTable]: The table for the user profile.
/// - [crudConfigurations]: The configurations for the CRUD operations.
/// - [userProfileInclude]: The include for the user profile. It's used to include related models in the user profile.
/// - [userProfileConstructor]: The constructor for the user profile. It's used to create a new user profile on registration.
/// - [alerts]: The alerts for the framework.
/// - [auth]: The auth module for the framework.
/// - [cloudStorage]: The cloud storage module for the framework.
///
/// It also contains the main methods for the framework:
/// - [init]: Initializes the framework.
/// - [getUserProfile]: Gets the user profile.
/// - [getUserProfileByIdentifier]: Gets the user profile by identifier.
class DwCore<UserProfileClass extends TableRow> {
  final Table userProfileTable;
  final Map<String, Map<String, DwCrudConfig>> _crudConfiguration = {};
  final Map<String, Map<String, DwCrudEntity>> _dtoConfiguration = {};

  /// Channel declarations, longest prefix first — see [canListenTo].
  final List<DwChannelConfig> _channelConfiguration = [];

  late final ColumnInt _userInfoIdColumn;
  late final ColumnString _userIdentifierColumn;

  final Include? _userProfileInclude;
  final Future<UserProfileClass> Function(
    Session session, {
    required DwAuthRequest registrationRequest,
  })
  _userProfileConstructor;
  final DwAlerts alerts;

  /// Auth module (optional)
  final DwAuth<UserProfileClass>? auth;

  final DwCloudStorage? cloudStorage;

  /// Initialize DartWay Core
  static DwCore<UserProfileClass> init<UserProfileClass extends TableRow>({
    required Table userProfileTable,
    required List<DwCrudConfig> crudConfigurations,
    required List<DwCrudEntity> dtoConfigurations,
    required List<DwChannelConfig> channelConfigurations,
    Include? userProfileInclude,
    required Future<UserProfileClass> Function(
      Session session, {
      required DwAuthRequest registrationRequest,
    })
    userProfileConstructor,
    required DwAlerts dwAlerts,
    DwAuthConfig<UserProfileClass>? dwAuthConfig,
    DwCloudStorageConfig? cloudStorageConfig,
  }) {
    final instance = DwCore<UserProfileClass>._(
      userProfileTable: userProfileTable,
      crudConfigurations: crudConfigurations,
      dtoConfigurations: dtoConfigurations,
      channelConfigurations: channelConfigurations,
      userProfileInclude: userProfileInclude,
      userProfileConstructor: userProfileConstructor,
      alerts: dwAlerts,
      auth: dwAuthConfig != null
          ? DwAuth<UserProfileClass>(config: dwAuthConfig)
          : null,
      cloudStorage: cloudStorageConfig != null
          ? DwCloudStorage(config: cloudStorageConfig)
          : null,
    );

    setDwInstance(instance);

    return instance;
  }

  DwCore._({
    required this.userProfileTable,
    required List<DwCrudConfig> crudConfigurations,
    required List<DwCrudEntity> dtoConfigurations,
    required List<DwChannelConfig> channelConfigurations,
    required Include? userProfileInclude,
    required Future<UserProfileClass> Function(
      Session session, {
      required DwAuthRequest registrationRequest,
    })
    userProfileConstructor,
    required this.alerts,
    required this.auth,
    required this.cloudStorage,
  }) : _userProfileInclude = userProfileInclude,
       _userProfileConstructor = userProfileConstructor {
    _userInfoIdColumn =
        userProfileTable.columns.firstWhereOrThrow(
              (column) =>
                  column is ColumnInt &&
                  column.columnName == DwCoreConst.userProfileIdColumnName,
              'User profile table must have an int ${DwCoreConst.userProfileIdColumnName} column',
            )
            as ColumnInt;

    _userIdentifierColumn =
        userProfileTable.columns.firstWhereOrThrow(
              (column) =>
                  column is ColumnString &&
                  column.columnName == DwCoreConst.userIdentifierColumnName,
              'User profile table must have a String ${DwCoreConst.userIdentifierColumnName} column',
            )
            as ColumnString;

    _crudConfiguration[DwCoreConst.dartwayInternalApi] = Map.fromEntries(
      [
        dwAuthRequestConfig,
        dwAuthVerificationConfig,
        dwAuthKeyConfig,
        DwCrudConfig<UserProfileClass>(
          table: userProfileTable,
          getModelConfigs: [
            DwGetModelConfig<UserProfileClass>(
              accessFilter: (session) async =>
                  _userInfoIdColumn.equals(session.signedInUserProfileId ?? 0),
              filterPrototype: DwBackendFilter.equalsPrototype(
                fieldName: DwCoreConst.userProfileIdColumnName,
              ),
              include: _userProfileInclude,
            ),
          ],
        ),
      ].map((config) => MapEntry(config.className, config)),
    );

    _dtoConfiguration[DwCoreConst.defaultApi] = Map.fromEntries(
      dtoConfigurations.map((config) => MapEntry(config.className, config)),
    );

    _crudConfiguration[DwCoreConst.defaultApi] = Map.fromEntries(
      crudConfigurations.map((config) => MapEntry(config.className, config)),
    );

    _channelConfiguration.addAll([
      // The two the framework names itself. `userUpdates$id` was the sharpest
      // edge of all: the name is a number away from every other user's, so it
      // was readable by anyone signed in, not just by its owner.
      const DwChannelConfig.owner(
        prefix: DwRealTimeEndpoint.userUpdatesChannelPrefix,
      ),
      const DwChannelConfig.public(prefix: DwCoreConst.publicUpdatesChannel),
      ...channelConfigurations,
    ]);

    // Sorted once at startup so `canListenTo` can take the first match: with
    // prefixes, `chatPost_admin_` and `chatPost_` both match the same name, and
    // the more specific one has to be the one that answers.
    _channelConfiguration.sort((a, b) => b.prefix.length - a.prefix.length);
  }

  /// Non-blocking, transaction-scoped advisory locks — `dw.advisoryLock`.
  DwAdvisoryLock get advisoryLock => const DwAdvisoryLock();

  DwCrudConfig<TableRow>? getCrudConfig(String className, {String? api}) =>
      _crudConfiguration[api ?? DwCoreConst.defaultApi]?[className];

  DwCrudEntity<SerializableModel>? getDtoConfig(
    String className, {
    String? api,
  }) => _dtoConfiguration[api ?? DwCoreConst.defaultApi]?[className];

  /// Whether [session] may listen to [channel].
  ///
  /// A channel no declaration matches is refused. That is the point of the
  /// list: a channel name is invented by whoever writes `broadcastTo`, arrives
  /// from the client as a bare string, and nothing else in the system can tell
  /// a real one from a guess. Declaring it is how the server learns the name is
  /// real and who it is for. See [DwChannelConfig].
  Future<bool> canListenTo(Session session, String channel) async {
    final config = _channelConfiguration.firstWhereOrNull(
      (candidate) => candidate.matches(channel),
    );

    if (config == null) return false;

    return config.allows(
      session,
      channel,
      userProfileId: session.signedInUserProfileId,
    );
  }

  Future<UserProfileClass?> getUserProfile(Session session, int userId) async {
    final profile = await session.db.findFirstRow<UserProfileClass>(
      where: _userInfoIdColumn.equals(userId),
      include: _userProfileInclude,
    );

    if (profile == null) {
      session.log('Warning: User profile not found for userId $userId');
    }

    return profile;
  }

  Future<UserProfileClass?> getUserProfileByIdentifier(
    Session session,
    String identifier,
  ) async {
    final profile = await session.db.findFirstRow<UserProfileClass>(
      where: _userIdentifierColumn.equals(identifier),
      include: _userProfileInclude,
    );

    if (profile == null) {
      session.log('Warning: User profile not found for identifier $identifier');
    }

    return profile;
  }

  Future<UserProfileClass?> currentUserProfile(Session session) async {
    final userId = session.signedInUserProfileId;
    if (userId == null) return null;
    return getUserProfile(session, userId);
  }

  Future<int> createUserProfile(
    Session session, {
    required DwAuthRequest registrationRequest,
  }) async {
    final profile = await session.db.insertRow(
      await _userProfileConstructor(
        session,
        registrationRequest: registrationRequest,
      ),
    );

    return profile.id!;
  }

  Future<DwAuthFailReason?> prevalidateAuthAttempt(
    Session session,
    DwAuthRequest authRequest,
  ) async {
    final preAuthValidation = auth?.config.preAuthValidation;
    if (preAuthValidation != null) {
      final userProfile = await getUserProfileByIdentifier(
        session,
        authRequest.userIdentifier,
      );
      return await preAuthValidation(
        session,
        authRequest: authRequest,
        userProfile: userProfile,
      );
    }
    return null;
  }
}
