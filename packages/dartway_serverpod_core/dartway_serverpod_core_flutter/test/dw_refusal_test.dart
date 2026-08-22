import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The refusal as it arrives from a server that knows the difference, and the
/// failure it used to be indistinguishable from.
const _refusalText = 'This message was already deleted';
const _failureText = 'Unexpected error while handling the saveModel request';

class _Note implements SerializableModel {
  const _Note({this.id});

  final int? id;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}

void main() {
  final alerts = <String>[];
  late DwRecordingServerTransport transport;
  // The app's `dw` is a global the application declares; a test holds the core
  // it built instead.
  late DwCore<ServerpodClientShared, _Note> core;

  // One core per test process — the singleton forbids re-creation. No custom
  // error policy, so the framework's own alerting is what runs.
  setUpAll(() {
    transport = DwRecordingServerTransport(
      classNames: <Type, String>{_Note: 'Note'},
    );
    core = DwCore<ServerpodClientShared, _Note>(
      config: const DwConfig(),
      transport: transport,
      dwAlerts: DwAlerts.init(logFunction: alerts.add),
      getUserId: (_) => null,
    );
    DwRepository.setupRepository(defaultModel: const _Note(id: 0));
  });

  setUp(() {
    transport.reset();
    alerts.clear();
  });

  group('processApiResponse', () {
    test('answers a refusal with a DwRefusal carrying the rule text', () {
      const response = DwApiResponse<bool>.refusal(_refusalText);

      expect(
        () => DwRepository.processApiResponse<bool>(
          response,
          updateListeners: false,
        ),
        throwsA(
          isA<DwRefusal>().having((e) => e.message, 'message', _refusalText),
        ),
      );
    });

    test('answers a failure with an ordinary exception, as before', () {
      const response = DwApiResponse<bool>(
        isOk: false,
        value: null,
        error: _failureText,
      );

      expect(
        () => DwRepository.processApiResponse<bool>(
          response,
          updateListeners: false,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e is DwRefusal,
            'is a refusal',
            isFalse,
          ),
        ),
      );
    });

    test('a permission denial is a refusal too', () {
      expect(
        () => DwRepository.processApiResponse<bool>(
          const DwApiResponse<bool>.forbidden(),
          updateListeners: false,
        ),
        throwsA(
          isA<DwRefusal>().having(
            (e) => e.message,
            'message',
            'Not enough permissions',
          ),
        ),
      );
    });

    test('an older server, which marks nothing, still reports failures', () {
      // The flag absent from the JSON is what a server built before it looks
      // like: every error stays an incident, exactly as it did.
      final response = DwApiResponse<bool>.fromJson(const {
        'isOk': false,
        'value': null,
        'error': _refusalText,
      });

      expect(response.isRefusal, isFalse);
      expect(
        () => DwRepository.processApiResponse<bool>(
          response,
          updateListeners: false,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('a save the server refused', () {
    test('reaches the caller as a DwRefusal, in the rule\'s words', () async {
      transport.answerSave = (_) async =>
          const DwApiResponse<DwModelWrapper>.refusal(_refusalText);

      await expectLater(
        const DwRepo().saveModel(const _Note(id: 7)),
        throwsA(
          isA<DwRefusal>().having((e) => e.message, 'message', _refusalText),
        ),
      );
    });
  });

  group('the framework error policy', () {
    test('does not alert a refusal', () {
      core.handleError(const DwRefusal(_refusalText), StackTrace.current);

      expect(alerts, isEmpty, reason: 'a rule saying no is not an incident');
    });

    test('still alerts everything else', () {
      core.handleError(StateError('boom'), StackTrace.current);

      expect(alerts, hasLength(1));
      expect(alerts.single, contains('boom'));
    });
  });
}
