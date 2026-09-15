import 'dart:convert';
import 'dart:io';

import 'package:dartway_push_firebase/dartway_push_firebase.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the shipped `web/firebase-messaging-sw.js` in Node with the Firebase
/// SDK stubbed the way it behaves, and clicks a notification — the click that
/// never worked (#78) is tested by running it, not by reading it.
Future<Map<String, Object?>> click(String scenario) async {
  final result = await Process.run('node', [
    'test/support/run_service_worker.js',
    'web/firebase-messaging-sw.js',
    scenario,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

void main() {
  final template = File('web/firebase-messaging-sw.js').readAsStringSync();

  test('the click handler is registered before the SDK is loaded', () {
    expect(
      template.indexOf("addEventListener('notificationclick'"),
      lessThan(template.indexOf('importScripts(')),
    );
  });

  test('reads the link under the key the server writes, and posts the type '
      'the app listens for', () {
    expect(template, contains('data.${DwPushData.linkKey}'));
    expect(template, contains("type: '${DwFirebasePush.webOpenMessageType}'"));
  });

  test(
    'a click with the app open focuses its tab and hands it the link',
    () async {
      final report = await click('open-tab');
      expect(report['order'], [
        'app:notificationclick',
        'sdk:notificationclick',
      ]);
      expect(report['sdkRan'], isFalse, reason: 'ours stops the SDK\'s');
      expect(report['closed'], isTrue);
      expect(report['focused'], 1);
      expect(report['opened'], isEmpty);
      final posted = report['posted']! as List;
      expect(posted, hasLength(1), reason: 'only the tab of this origin');
      final message = posted.single as Map;
      expect(message['type'], DwFirebasePush.webOpenMessageType);
      expect(message['link'], '/news/12?from=push');
      expect((message['data'] as Map)[DwPushData.typeKey], 'NewsAlert');
    },
  );

  test(
    'a click with the app closed opens the link on the app origin',
    () async {
      final report = await click('no-tab');
      expect(report['sdkRan'], isFalse);
      expect(report['opened'], ['https://app.example.com/news/12?from=push']);
    },
  );

  test('a notification without a link opens the app root', () async {
    final report = await click('no-data');
    expect(report['opened'], ['https://app.example.com/']);
  });
}
