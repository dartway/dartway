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
/// - [normalizeAuthIdentifier]: Brings an identifier to the form this app stores.
class DwCore<UserProfileClass extends TableRow> {
  final Table userProfileTable;
  final Map<String, Map<String, DwCrudConfig>> _crudConfiguration = {};
  final Map<String, Map<String, DwCrudEntity>> _dtoConfiguration = {};

  /// Channel declarations, longest prefix first — see [canListenTo].
  final List<DwChannelConfig> _channelConfiguration = [];

  late final ColumnInt _userInfoIdColumn;

  /// The `userIdentifier` column, when the app leaves the lookup to the core.
  /// Null when [DwAuthConfig.findUserProfileByIdentifier] answers instead — an
  /// app that finds an account by its own columns is not asked for a column it
  /// never reads.
  late final ColumnString? _userIdentifierColumn;

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

    // Required only while the core does the looking up. The check stays a boot
    // failure rather than a first-sign-in failure: a missing column is a fact
    // about the schema, and the schema is known here.
    _userIdentifierColumn = auth?.config.findUserProfileByIdentifier != null
        ? null
        : userProfileTable.columns.firstWhereOrThrow(
                (column) =>
                    column is ColumnString &&
                    column.columnName == DwCoreConst.userIdentifierColumnName,
                'User profile table must have a String ${DwCoreConst.userIdentifierColumnName} column, '
                'or DwAuthConfig.findUserProfileByIdentifier must say how to find an account',
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
      const DwChannelConfig.owner(prefix: DwCoreConst.userUpdatesChannelPrefix),
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

  /// Generic, model-agnostic database access for [session] — `dw.db(session)`.
  ///
  /// For an operation shared by several models, where Serverpod's per-model
  /// repositories cannot help. See [DwDb] for what it is and why it is not a
  /// second `session.db`.
  DwDb db(Session session) => DwDb(session);

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

  /// The profile row for [userId], or `null` when there is none.
  ///
  /// **Pass [transaction] when you are inside one** — a CRUD save hook has it as
  /// `saveContext.transaction`. Omitted, the read runs on its own connection:
  /// blind to the uncommitted rows around it in production, and under
  /// `serverpod_test` with database rollbacks enabled (the default) it fails
  /// outright as a concurrent database call, which makes the config
  /// untestable rather than merely stale.
  ///
  /// When all you need is the caller's id, `session.signedInUserProfileId` is
  /// synchronous and costs no query at all.
  Future<UserProfileClass?> getUserProfile(
    Session session,
    int userId, {
    Transaction? transaction,
  }) async {
    final profile = await session.db.findFirstRow<UserProfileClass>(
      where: _userInfoIdColumn.equals(userId),
      include: _userProfileInclude,
      transaction: transaction,
    );

    if (profile == null) {
      session.log('Warning: User profile not found for userId $userId');
    }

    return profile;
  }

  /// The profile row carrying [identifier], or `null` when there is none.
  ///
  /// [identifier] is put through [normalizeAuthIdentifier] first, so a caller
  /// holding an address a human typed does not have to remember the app's own
  /// rule. Without a rule configured this is an exact match, as it always was.
  ///
  /// [transaction] carries the same meaning as on [getUserProfile].
  /// An app that can be signed into by more than one value — a phone *or* an
  /// email on one account — answers this itself through
  /// [DwAuthConfig.findUserProfileByIdentifier]; then that function is the
  /// lookup and the `userIdentifier` column is not consulted at all.
  Future<UserProfileClass?> getUserProfileByIdentifier(
    Session session,
    String identifier, {
    Transaction? transaction,
  }) async {
    final normalized = normalizeAuthIdentifier(identifier);

    final findByApp = auth?.config.findUserProfileByIdentifier;
    final identifierColumn = _userIdentifierColumn;

    final profile = findByApp != null
        ? await findByApp(session, normalized, transaction: transaction)
        : await session.db.findFirstRow<UserProfileClass>(
            where: identifierColumn!.equals(normalized),
            include: _userProfileInclude,
            transaction: transaction,
          );

    if (profile == null) {
      session.log('Warning: User profile not found for identifier $normalized');
    }

    return profile;
  }

  /// [identifier] in the form this app stores identifiers in — see
  /// [DwAuthConfig.normalizeIdentifier].
  ///
  /// Returns the value untouched when the app runs without the auth module at
  /// all — there is no other way to get an unrewritten identifier now, since
  /// [DwAuthConfig.normalizeIdentifier] is required. Public because an app has its own
  /// paths that write or match an identifier — a seed, an admin tool, an
  /// invitation — and the whole point is that they state the rule once rather
  /// than each carrying a copy of it.
  String normalizeAuthIdentifier(String identifier) =>
      auth?.config.normalizeIdentifier(identifier) ?? identifier;

  /// The signed-in caller's profile row, or `null` for a caller with no session.
  ///
  /// [transaction] carries the same meaning as on [getUserProfile].
  Future<UserProfileClass?> currentUserProfile(
    Session session, {
    Transaction? transaction,
  }) async {
    final userId = session.signedInUserProfileId;
    if (userId == null) return null;
    return getUserProfile(session, userId, transaction: transaction);
  }

  /// Whether this app has said where a verified identifier goes — that is,
  /// whether `DwAuthRequestType.changeIdentifier` can complete at all.
  ///
  /// A getter rather than a read of the field at the call site, and the
  /// difference is not style. `dw` is the raw `DwCore`, so a caller reading
  /// [DwAuthConfig.attachVerifiedIdentifier] through it reads a function that
  /// takes `dynamic` where the real one takes the app's profile type — and a
  /// function is contravariant in its parameters, so that read throws at
  /// runtime rather than failing to compile. Inside this class the type
  /// argument is the real one and the read is sound.
  bool get canAttachVerifiedIdentifier =>
      auth?.config.attachVerifiedIdentifier != null;

  /// Writes an identifier its owner has just verified onto their profile, and
  /// answers with the profile as it now stands.
  ///
  /// The app decides where the value goes — see
  /// [DwAuthConfig.attachVerifiedIdentifier]. Returns `null` when no app has
  /// said how, which the caller treats as a refusal: an identifier verified and
  /// then not written is the worst of the three outcomes.
  Future<UserProfileClass?> attachVerifiedIdentifier(
    Session session, {
    required int userId,
    required DwAuthRequest verifiedRequest,
    Transaction? transaction,
  }) async {
    final attach = auth?.config.attachVerifiedIdentifier;
    if (attach == null) return null;

    final profile = await getUserProfile(
      session,
      userId,
      transaction: transaction,
    );
    if (profile == null) return null;

    return attach(
      session,
      userProfile: profile,
      verifiedRequest: verifiedRequest,
    );
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
