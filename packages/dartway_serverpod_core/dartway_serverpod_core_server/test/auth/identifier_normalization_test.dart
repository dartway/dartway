// `findFirstRow` is internal to Serverpod; the double below has to implement it
// to catch the query the lookup makes.
// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/crud/dw_auth_request_config.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The address as a human typed it the second time: a stray space from the
/// keyboard's autocomplete, and a capital the phone put there.
const _asTyped = ' Ivan@Acme.COM ';

/// The one form the app decided to store it in.
const _stored = 'ivan@acme.com';

class TestUserProfile implements TableRow<int?> {
  @override
  int? get id => 1;

  @override
  Table<int?> get table => _userProfileTable;

  @override
  Map<String, dynamic> toJson() => const {};
}

class TestTable extends Table<int?> {
  TestTable(String name) : super(tableName: name) {
    userIdentifier = ColumnString(DwCoreConst.userIdentifierColumnName, this);
  }

  late final ColumnString userIdentifier;

  @override
  List<Column> get columns => [id, userIdentifier];
}

final _userProfileTable = TestTable('test_user_profile');

/// Catches the query instead of running it: what these tests are about is which
/// identifier the framework asks the database for, and that is decided before
/// any row exists. Every lookup answers "no such profile".
class RecordingDatabase implements Database {
  final whereClauses = <String>[];

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
  }) async {
    whereClauses.add(where.toString());
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected database call: ${invocation.memberName}');
}

class RecordingSession implements Session {
  final RecordingDatabase database = RecordingDatabase();

  @override
  Database get db => database;

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

DwAuthRequest _loginRequest(String identifier) => DwAuthRequest(
  requestType: DwAuthRequestType.login,
  userIdentifier: identifier,
  authProvider: DwAuthProvider.email,
);

DwSaveContext<DwAuthRequest> _insertOf(DwAuthRequest request) =>
    DwSaveContext<DwAuthRequest>(
      currentUserId: null,
      isInsert: true,
      initialModel: null,
      currentModel: request,
    );

void main() {
  // A `where` clause renders its values through the encoder the live database
  // installs, and no database is created here. Postgres' own encoder does the
  // rendering without a connection, which is all these assertions read.
  ValueEncoder.set(PostgresValueEncoder());

  // `DwCore.init` resolves class names through `Serverpod.instance`. Nothing
  // here is started; no socket and no database is touched.
  Serverpod(
    ['--mode', 'test', '--role', 'monolith'],
    Protocol(),
    Endpoints(),
    config: ServerpodConfig.defaultConfig(),
  );

  final dw = DwCore.init<TestUserProfile>(
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
    ),
  );

  group('with a normalization rule declared', () {
    test('the profile lookup asks for the stored form', () async {
      final session = RecordingSession();

      await dw.getUserProfileByIdentifier(session, _asTyped);

      expect(session.database.whereClauses.single, contains(_stored));
      expect(session.database.whereClauses.single, isNot(contains('Acme')));
    });

    test('an arriving auth request is rewritten before anything reads it', () async {
      final request = _loginRequest(_asTyped);

      await dwAuthRequestConfig.saveConfig!.beforeSaveTransaction!(
        RecordingSession(),
        _insertOf(request),
      );

      // The one field every later step reads: the lock, the rate-limit bucket
      // and the profile a registration builds all take the identifier from
      // here, so they cannot disagree about who this is.
      expect(request.userIdentifier, _stored);
    });

    test(
      'the same address typed twice resolves to one account, not two',
      () async {
        // The defect: a profile stored under `_stored` was not found for
        // `_asTyped`, the request was resolved as a registration, and the
        // person got a second, empty account.
        final session = RecordingSession();
        final request = _loginRequest(_asTyped);

        await dwAuthRequestConfig.saveConfig!.beforeSaveTransaction!(
          session,
          _insertOf(request),
        );

        expect(
          session.database.whereClauses,
          everyElement(contains(_stored)),
          reason: 'the sign-in looked for an address the registration would '
              'never have written',
        );
      },
    );
  });

  group('with no rule declared', () {
    test('the identifier is left exactly as it was typed', () {
      const config = DwAuthConfig<TestUserProfile>(passwords: {});

      expect(config.normalizeIdentifier(_asTyped), _asTyped);
    });
  });
}
