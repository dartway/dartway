import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/endpoints/dw_crud_endpoint.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The failure the issue was written about: the table is not in the database
/// yet, or a filter names a column the schema never grew. It comes out of the
/// config, below the endpoint, and it is thrown — never returned.
///
/// Its own function so the top frame of the stack has a name to look for: the
/// point of the stack-trace test is that the report points *here* and not at
/// the handler that caught it.
Never tableIsMissing() =>
    throw StateError('relation "broken_list" does not exist');

class BrokenList implements TableRow<int?> {
  @override
  int? get id => null;

  @override
  Table<int?> get table => _brokenListTable;

  @override
  Map<String, dynamic> toJson() => const {};
}

class PrivateList implements TableRow<int?> {
  @override
  int? get id => null;

  @override
  Table<int?> get table => _brokenListTable;

  @override
  Map<String, dynamic> toJson() => const {};
}

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

final _brokenListTable = TestTable('broken_list');
final _userProfileTable = TestTable('test_user_profile');

/// A list config that fails the way a broken list does in production: on the
/// way to the rows, before there is anything to answer with.
class ExplodingListConfig<T extends TableRow> extends DwGetModelListConfig<T> {
  const ExplodingListConfig({super.allowAnonymous}) : super(accessFilter: null);

  @override
  Future<DwApiResponse<List<DwModelWrapper>>> getModelList(
    Session session, {
    Expression? whereClause,
    List<Order>? orderByList,
    int? limit,
    int? offset,
  }) async => tableIsMissing();

  @override
  Future<DwApiResponse<int>> getCount(
    Session session, {
    Expression? whereClause,
  }) async => tableIsMissing();
}

class ExplodingDeleteConfig<T extends TableRow> extends DwDeleteConfig<T> {
  const ExplodingDeleteConfig({super.allowAnonymous});

  @override
  Future<DwApiResponse<bool>> delete(Session session, int modelId) async =>
      tableIsMissing();
}

/// A session carrying nothing but its authentication: the endpoint decides
/// access from `signedInUserProfileId`, and logs. Anything else it is asked
/// for means a test reached the database, which none of these should.
class TestSession implements Session {
  TestSession.anonymous() : userIdentifier = null;

  TestSession.signedIn(int userProfileId)
    : userIdentifier = userProfileId.toString();

  final String? userIdentifier;

  @override
  AuthenticationInfo? get authenticated {
    final identifier = userIdentifier;
    if (identifier == null) return null;
    return AuthenticationInfo(identifier, const <Scope>{}, authId: 'test');
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
      throw StateError('The endpoint must not reach the database here');
}

void main() {
  // `DwCore.init` builds the framework's own config for the signed-in profile,
  // and `DwBackendFilter.equalsPrototype` resolves its class name through
  // `Serverpod.instance` — so the core cannot be initialized before a Serverpod
  // object exists. Constructing one is enough; nothing here is started, and no
  // socket or database is touched.
  Serverpod(
    ['--mode', 'test', '--role', 'monolith'],
    Protocol(),
    Endpoints(),
    config: ServerpodConfig.defaultConfig(),
  );

  final reports = <String>[];
  final endpoint = DwCrudEndpoint();
  final session = TestSession.signedIn(42);

  DwCore.init<TestUserProfile>(
    userProfileTable: _userProfileTable,
    crudConfigurations: [
      DwCrudConfig<BrokenList>(
        table: _brokenListTable,
        getListConfig: const ExplodingListConfig<BrokenList>(
          allowAnonymous: true,
        ),
        deleteConfig: const ExplodingDeleteConfig<BrokenList>(
          allowAnonymous: true,
        ),
      ),
      DwCrudConfig<PrivateList>(
        table: _brokenListTable,
        getListConfig: const ExplodingListConfig<PrivateList>(),
      ),
    ],
    dtoConfigurations: [],
    channelConfigurations: [],
    userProfileConstructor: (session, {required registrationRequest}) async =>
        throw UnimplementedError(),
    dwAlerts: DwAlerts.init(logFunction: reports.add),
  );

  setUp(reports.clear);

  group('a thrown failure', () {
    test('getAll answers with a failure naming the model', () async {
      final response = await endpoint.getAll(session, className: 'BrokenList');

      expect(response.isOk, isFalse);
      expect(response.error, contains('getAll'));
      expect(response.error, contains('BrokenList'));
    });

    test('getCount answers with a failure naming the model', () async {
      final response = await endpoint.getCount(
        session,
        className: 'BrokenList',
      );

      expect(response.isOk, isFalse);
      expect(response.error, contains('getCount'));
      expect(response.error, contains('BrokenList'));
    });

    test('delete keeps the id of the row it was about', () async {
      final response = await endpoint.delete(
        session,
        className: 'BrokenList',
        modelId: 7,
      );

      expect(response.isOk, isFalse);
      expect(response.error, contains('BrokenList'));
      expect(response.error, contains('id 7'));
    });

    test('is reported to dw.alerts, once', () async {
      await endpoint.getAll(session, className: 'BrokenList');

      expect(reports, hasLength(1));
      expect(reports.single, contains('BrokenList'));
      expect(reports.single, contains('relation'));
    });
  });

  group('the reported stack trace', () {
    /// The frames of the `📜 StackTrace` code block of an alert.
    List<String> framesOf(String report) {
      final open = report.indexOf('```');
      final close = report.lastIndexOf('```');
      expect(open, greaterThan(-1), reason: 'the alert carries no stack trace');
      return report.substring(open + 3, close).trim().split('\n');
    }

    test('is the stack of the throw, not of the handler', () async {
      await endpoint.getAll(session, className: 'BrokenList');

      final frames = framesOf(reports.single);

      // The whole of the regression: reporting `StackTrace.current` from
      // inside the handler compiles, reads as handled, and points every
      // report at the handler instead of at the code that failed.
      expect(frames.first, contains('tableIsMissing'));

      // `returnError` can only appear in a stack that was captured inside it —
      // which is exactly what the discarded `stackTrace` argument used to be
      // replaced by. `_guard` does appear, and belongs there: it is the
      // asynchronous suspension the throw travelled through.
      expect(reports.single, isNot(contains('returnError')));
    });
  });

  group('what the guard must leave alone', () {
    test('an unregistered model is still "not configured"', () async {
      final response = await endpoint.getAll(session, className: 'NoSuchModel');

      expect(response.isOk, isFalse);
      expect(response.error, contains('Action not configured on server'));
      expect(reports, isEmpty, reason: 'a denial is an answer, not an error');
    });

    test('an anonymous caller is still "authentication required"', () async {
      final response = await endpoint.getAll(
        TestSession.anonymous(),
        className: 'PrivateList',
      );

      expect(response.isOk, isFalse);
      expect(response.error, contains('Authentication required'));
      // The config would have thrown had the gate let the call through — the
      // guard must not turn a denial into an error, nor the other way round.
      expect(reports, isEmpty);
    });
  });
}
