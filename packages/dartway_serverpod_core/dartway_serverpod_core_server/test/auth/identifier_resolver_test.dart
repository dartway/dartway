// `findFirstRow` is internal to Serverpod; the double below has to implement it
// to prove the core does *not* call it once the app answers the lookup itself.
// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The address as a human typed it.
const _asTyped = ' Ivan@Acme.COM ';

/// The one form the app decided to store it in.
const _stored = 'ivan@acme.com';

class TestUserProfile implements TableRow<int?> {
  @override
  int? get id => 1;

  @override
  Table<int?> get table => _tableWithoutIdentifier;

  @override
  Map<String, dynamic> toJson() => const {};
}

/// A profile table that carries **no** `userIdentifier` column — the shape an
/// app takes once an account can be reached by more than one value.
class TableWithoutIdentifier extends Table<int?> {
  TableWithoutIdentifier(String name) : super(tableName: name) {
    phone = ColumnString('phone', this);
    email = ColumnString('email', this);
  }

  late final ColumnString phone;
  late final ColumnString email;

  @override
  List<Column> get columns => [id, phone, email];
}

final _tableWithoutIdentifier = TableWithoutIdentifier('test_user_profile');

/// Fails the test if the core reaches for the database at all: with a resolver
/// configured, the lookup is the app's and the core has nothing to query.
class ForbiddenDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'The core queried the database: ${invocation.memberName}',
  );
}

class RecordingSession implements Session {
  @override
  Database get db => ForbiddenDatabase();

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

void main() {
  // `DwCore.init` resolves class names through `Serverpod.instance`. Nothing
  // here is started; no socket and no database is touched.
  Serverpod(
    ['--mode', 'test', '--role', 'monolith'],
    Protocol(),
    Endpoints(),
    config: ServerpodConfig.defaultConfig(),
  );

  final askedFor = <String>[];
  final profile = TestUserProfile();

  final dw = DwCore.init<TestUserProfile>(
    userProfileTable: _tableWithoutIdentifier,
    crudConfigurations: [],
    dtoConfigurations: [],
    channelConfigurations: [],
    userProfileConstructor: (session, {required registrationRequest}) async =>
        throw UnimplementedError(),
    dwAlerts: DwAlerts.init(logFunction: (_) {}),
    dwAuthConfig: DwAuthConfig<TestUserProfile>(
      passwords: const {},
      normalizeIdentifier: (identifier) => identifier.trim().toLowerCase(),
      // One account, two ways in — the case the `userIdentifier` column cannot
      // express, and the reason this seam exists.
      findUserProfileByIdentifier: (session, identifier, {transaction}) async {
        askedFor.add(identifier);
        return identifier == _stored || identifier == '79991235544'
            ? profile
            : null;
      },
    ),
  );

  group('with the lookup answered by the app', () {
    setUp(askedFor.clear);

    test('the core boots without a userIdentifier column', () {
      // The assertion is that `DwCore.init` above returned at all: it used to
      // throw here, and a table with no such column is exactly what an app
      // holding phone and email separately has.
      expect(dw.userProfileTable.columns.map((column) => column.columnName), [
        'id',
        'phone',
        'email',
      ]);
    });

    test('the resolver answers, and the core queries nothing itself', () async {
      final found = await dw.getUserProfileByIdentifier(
        RecordingSession(),
        _asTyped,
      );

      expect(found, same(profile));
    });

    test(
      'the resolver is handed the normalized form, not what was typed',
      () async {
        await dw.getUserProfileByIdentifier(RecordingSession(), _asTyped);

        // The app states the rule once, in `normalizeIdentifier`; applying it a
        // second time inside the resolver is how the two copies start to differ.
        expect(askedFor.single, _stored);
      },
    );

    test('either value reaches the same account', () async {
      final byEmail = await dw.getUserProfileByIdentifier(
        RecordingSession(),
        _asTyped,
      );
      final byPhone = await dw.getUserProfileByIdentifier(
        RecordingSession(),
        '79991235544',
      );

      expect(byPhone, same(byEmail));
    });

    test(
      'an identifier nobody holds is still a registration, not an error',
      () async {
        final found = await dw.getUserProfileByIdentifier(
          RecordingSession(),
          'nobody@acme.com',
        );

        expect(found, isNull);
      },
    );
  });
}
