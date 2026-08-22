import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/endpoints/dw_crud_endpoint.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The distinction this file is about: a rule that says no, and a server that
/// broke. Both leave `actionProcessing` without a result, and until the
/// rejection channel existed both arrived at the user as "Application error"
/// and at the operator as an alert.
const _rejectionText = 'This message was already deleted';
const _validationText = 'You have no access to this track';

/// A failure of the kind alerts exist for: nothing to do with the caller.
Never theDatabaseIsGone() =>
    throw StateError('relation "chat_post" does not exist');

/// The DTO an action is driven by: serializable, and deliberately not a
/// [TableRow] — that is the branch of `saveModel` that reaches a DTO config.
class TrackAction implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => const {};
}

/// The wrapper as it arrives from a client, with the class name the endpoint
/// looks its config up by.
///
/// The name normally comes from the serialization manager, which only knows
/// the models of a generated protocol; a test DTO is not in one, so it is
/// stated here instead. Nothing else about the wrapper changes.
class TestWrapper extends DwModelWrapper {
  TestWrapper(SerializableModel object, this._className)
    : super(object: object);

  final String _className;

  @override
  String get className => _className;
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

final _userProfileTable = TestTable('test_user_profile');

/// A transaction handle that only has to exist: the action receives it and
/// hands it to the repositories it reads through, none of which run here.
class FakeTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The action must not use the transaction here');
}

/// Runs the transaction body and lets whatever it throws travel outwards —
/// which is the one behaviour of a real transaction these tests depend on, and
/// the reason a refusal has to be thrown rather than returned.
class FakeDatabase implements Database {
  @override
  Future<R> transaction<R>(
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async => transactionFunction(FakeTransaction());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The action must not reach the database here');
}

/// A session carrying its authentication and a database that can open a
/// transaction. Anything else it is asked for is a test reaching further than
/// it meant to.
class TestSession implements Session {
  TestSession.signedIn(int userProfileId)
    : userIdentifier = userProfileId.toString();

  final String userIdentifier;

  @override
  AuthenticationInfo? get authenticated =>
      AuthenticationInfo(userIdentifier, const <Scope>{}, authId: 'test');

  @override
  Database get db => FakeDatabase();

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
  // `DwCore.init` resolves class names through `Serverpod.instance`, so the
  // core cannot be initialized before a Serverpod object exists. Constructing
  // one is enough; nothing is started and no socket is touched.
  Serverpod(
    ['--mode', 'test', '--role', 'monolith'],
    Protocol(),
    Endpoints(),
    config: ServerpodConfig.defaultConfig(),
  );

  final reports = <String>[];
  final endpoint = DwCrudEndpoint();
  final session = TestSession.signedIn(42);

  // Set by the actions, read by the tests: what actually ran.
  var actionRan = false;
  var sideEffectRan = false;

  DwCore.init<TestUserProfile>(
    userProfileTable: _userProfileTable,
    crudConfigurations: [],
    dtoConfigurations: [
      // Refuses before the transaction opens, by returning the text.
      DwDtoActionConfig<TrackAction>(
        validateAction: (session, dto) async => _validationText,
        actionProcessing: (session, transaction, dto) async {
          actionRan = true;
          return [];
        },
      ),
      // Refuses from inside the transaction, by throwing the rejection.
      DwDtoActionConfig<RejectingAction>(
        actionProcessing: (session, transaction, dto) async =>
            throw const DwActionRejection(_rejectionText),
        afterSaveSideEffects: (session, dto, updatedModels) async =>
            sideEffectRan = true,
      ),
      // Breaks, the way a server breaks.
      DwDtoActionConfig<BrokenAction>(
        actionProcessing: (session, transaction, dto) async =>
            theDatabaseIsGone(),
      ),
      // Does its work and says yes — the control for all of the above.
      DwDtoActionConfig<PassingAction>(
        validateAction: (session, dto) async => null,
        actionProcessing: (session, transaction, dto) async {
          actionRan = true;
          return [];
        },
      ),
    ],
    channelConfigurations: [],
    userProfileConstructor: (session, {required registrationRequest}) async =>
        throw UnimplementedError(),
    dwAlerts: DwAlerts.init(logFunction: reports.add),
  );

  setUp(() {
    reports.clear();
    actionRan = false;
    sideEffectRan = false;
  });

  /// Sends [dto] the way a client does: wrapped, under the name of its own
  /// type — which is the name its config is registered under.
  Future<DwApiResponse<DwModelWrapper>> saveModel(TrackAction dto) =>
      endpoint.saveModel(
        session,
        wrappedModel: TestWrapper(dto, dto.runtimeType.toString()),
      );

  group('a refusal from validateAction', () {
    test('answers with the text the rule was written in', () async {
      final response = await saveModel(TrackAction());

      expect(response.isOk, isFalse);
      expect(response.error, _validationText);
    });

    test('is not reported to dw.alerts', () async {
      await saveModel(TrackAction());

      expect(reports, isEmpty, reason: 'a refusal is an answer, not an error');
    });

    test('stops the action before it runs', () async {
      await saveModel(TrackAction());

      expect(actionRan, isFalse);
    });
  });

  group('a refusal thrown from inside the action', () {
    test('answers with the text the rule was written in', () async {
      final response = await saveModel(RejectingAction());

      expect(response.isOk, isFalse);
      // Verbatim, and in particular not rewritten by the endpoint's guard:
      // the whole point is that the user reads this and not "Unexpected
      // error while handling the saveModel request".
      expect(response.error, _rejectionText);
    });

    test('is not reported to dw.alerts', () async {
      await saveModel(RejectingAction());

      expect(reports, isEmpty);
    });

    test('does not fire the side effects', () async {
      await saveModel(RejectingAction());
      // The hook is unawaited, so give the microtask that would run it a turn.
      await Future<void>.delayed(Duration.zero);

      expect(sideEffectRan, isFalse);
    });
  });

  group('a real failure', () {
    test('is still wrapped in the guard\'s message', () async {
      final response = await saveModel(BrokenAction());

      expect(response.isOk, isFalse);
      expect(response.error, contains('Unexpected error'));
      expect(response.error, contains('saveModel'));
      expect(response.error, contains('BrokenAction'));
    });

    test('is still reported to dw.alerts, with the cause', () async {
      await saveModel(BrokenAction());

      expect(reports, hasLength(1));
      expect(reports.single, contains('BrokenAction'));
      expect(reports.single, contains('relation'));
    });
  });

  group('an action that says yes', () {
    test('still answers isOk, and alerts nobody', () async {
      final response = await saveModel(PassingAction());

      expect(response.isOk, isTrue);
      expect(response.error, isNull);
      expect(actionRan, isTrue);
      expect(reports, isEmpty);
    });
  });
}

/// The DTOs are one class each because a config is registered under the name
/// of its type: four behaviours, four names for the endpoint to resolve.
class RejectingAction extends TrackAction {}

class BrokenAction extends TrackAction {}

class PassingAction extends TrackAction {}
