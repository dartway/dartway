// The doubles below stand in for Serverpod's database and session, both of
// which are internal to it.
// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_request_extension.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The person doing the changing.
const _callerProfileId = 42;

/// The address they are moving onto their account.
const _newAddress = 'ivan@acme.com';

class TestUserProfile implements TableRow<int?> {
  TestUserProfile({required this.id, this.email});

  @override
  final int? id;

  final String? email;

  @override
  Table<int?> get table => _userProfileTable;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'email': email};
}

class TestTable extends Table<int?> {
  TestTable(String name) : super(tableName: name) {
    email = ColumnString('email', this);
  }

  late final ColumnString email;

  @override
  List<Column> get columns => [id, email];
}

final _userProfileTable = TestTable('test_user_profile');

/// Answers the one read the flow makes — the caller's own row — and refuses
/// everything else, so a test that starts touching the database says so.
class ProfileDatabase implements Database {
  ProfileDatabase(this.storedProfile);

  final TestUserProfile? storedProfile;

  @override
  Future<T?> findFirstRow<T extends TableRow>({
    Expression? where,
    int? offset,
    Column? orderBy,
    List<Order>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async => storedProfile as T?;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected database call: ${invocation.memberName}');
}

class TestSession implements Session {
  TestSession({required this.callerProfileId, TestUserProfile? storedProfile})
    : database = ProfileDatabase(
        storedProfile ?? TestUserProfile(id: callerProfileId),
      );

  TestSession.anonymous()
    : callerProfileId = null,
      database = ProfileDatabase(null);

  final int? callerProfileId;
  final ProfileDatabase database;

  @override
  Database get db => database;

  @override
  AuthenticationInfo? get authenticated {
    final id = callerProfileId;
    if (id == null) return null;
    return AuthenticationInfo('$id', const <Scope>{}, authId: 'test');
  }

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected session call: ${invocation.memberName}');
}

DwAuthRequest _changeRequest(String identifier) => DwAuthRequest(
  requestType: DwAuthRequestType.changeIdentifier,
  userIdentifier: identifier,
  authProvider: DwAuthProvider.email,
);

void main() {
  Serverpod(
    ['--mode', 'test', '--role', 'monolith'],
    Protocol(),
    Endpoints(),
    config: ServerpodConfig.defaultConfig(),
  );

  final written = <String>[];

  DwCore.init<TestUserProfile>(
    userProfileTable: _userProfileTable,
    crudConfigurations: [],
    dtoConfigurations: [],
    channelConfigurations: [],
    userProfileConstructor: (session, {required registrationRequest}) async =>
        throw UnimplementedError(),
    dwAlerts: DwAlerts.init(logFunction: (_) {}),
    dwAuthConfig: DwAuthConfig<TestUserProfile>(
      passwords: const {},
      normalizeIdentifier: (identifier) => identifier.trim().toLowerCase(),
      // The shape this flow exists for: an account reachable by its own
      // columns, so there is no `userIdentifier` column to boot against.
      // These tests hand `tryVerify` the lookup's answer directly, so what
      // this returns never matters — that it is set does.
      findUserProfileByIdentifier: (session, identifier, {transaction}) async =>
          null,
      attachVerifiedIdentifier:
          (session, {required userProfile, required verifiedRequest}) async {
            written.add(verifiedRequest.userIdentifier);
            return TestUserProfile(
              id: userProfile.id,
              email: verifiedRequest.userIdentifier,
            );
          },
    ),
  );

  group('changing an identifier', () {
    setUp(written.clear);

    test('a free address on a signed-in account waits for its code', () async {
      final request = _changeRequest(_newAddress);

      await request.tryVerify(
        TestSession(callerProfileId: _callerProfileId),
        // Nobody holds this address — the happy path, and the mirror image of
        // a sign-in, where finding nobody is the failure.
        userProfile: null,
      );

      expect(request.status, DwAuthRequestStatus.pendingVerification);
    });

    test(
      'the account changed is the caller, not what the request claims',
      () async {
        final request = _changeRequest(_newAddress)
          // What a hostile client would send: somebody else's profile id.
          ..userId = 7;

        await request.tryVerify(
          TestSession(callerProfileId: _callerProfileId),
          userProfile: null,
        );

        expect(request.userId, _callerProfileId);
      },
    );

    test('an address somebody already holds is refused', () async {
      final request = _changeRequest(_newAddress);

      await request.tryVerify(
        TestSession(callerProfileId: _callerProfileId),
        // Another account carries it. Registering a second owner for one
        // address is exactly what the sign-in lookup would then resolve
        // arbitrarily.
        userProfile: TestUserProfile(id: 7, email: _newAddress),
      );

      expect(request.status, DwAuthRequestStatus.failed);
      expect(request.failReason, DwAuthFailReason.userAlreadyExists);
    });

    test(
      'a caller with no session is refused before any code is sent',
      () async {
        final request = _changeRequest(_newAddress);

        await request.tryVerify(TestSession.anonymous(), userProfile: null);

        expect(request.status, DwAuthRequestStatus.failed);
        expect(request.failReason, DwAuthFailReason.userNotFound);
      },
    );

    test(
      'a verified request writes the identifier and answers with the profile',
      () async {
        final request = _changeRequest(_newAddress)..userId = _callerProfileId;

        final result = await request.onVerified(
          TestSession(callerProfileId: _callerProfileId),
          // The lookup found nobody — that is what made this address claimable.
          userProfile: null,
        );

        expect(written.single, _newAddress);
        expect(result.single.object, isA<TestUserProfile>());
        expect((result.single.object as TestUserProfile).email, _newAddress);
        expect(
          (result.single.object as TestUserProfile).id,
          _callerProfileId,
          reason: 'the profile handed back is the caller’s own',
        );
      },
    );
  });
}
