import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  decodeStudioBridgeMessage,
  encodeStudioBridgeMessage,
  studioBridgeProtocol,
  type StudioBridgeMessage,
} from '../src/index.ts';

/**
 * The strings below are the wire format as the Dart implementation writes it —
 * key order included. They are the whole point of this file: an app on this
 * package has to connect to a Studio that was never told it exists, so drift is
 * only cheap while it is caught here.
 */
describe('the wire format matches the Dart implementation byte for byte', () => {
  test('appReady', () => {
    assert.equal(
      encodeStudioBridgeMessage({ type: 'appReady' }),
      '{"dartwayStudioBridge":4,"type":"appReady","payload":{}}',
    );
  });

  test('manifest — the handshake response', () => {
    assert.equal(
      encodeStudioBridgeMessage({
        type: 'manifest',
        manifest: { projectName: 'Demo', zones: [] },
        currentPath: '/schedule',
        session: { isSignedIn: false },
        features: [],
        currentLocale: 'en',
      }),
      '{"dartwayStudioBridge":4,"type":"manifest","payload":{' +
        '"manifest":{"projectName":"Demo","zones":[],"features":[],"supportedLocales":[]},' +
        '"currentPath":"/schedule",' +
        '"session":{"isSignedIn":false,"isBusy":false},' +
        '"features":[],' +
        '"currentLocale":"en"}}',
    );
  });

  test('manifest — a zone with a screen passport', () => {
    assert.equal(
      encodeStudioBridgeMessage({
        type: 'manifest',
        manifest: {
          projectName: 'Demo',
          zones: [
            {
              label: 'Client app',
              rootPath: '/schedule',
              access: 'signedIn',
              screens: [
                {
                  path: '/schedule/profile',
                  parentPath: '/schedule',
                  title: 'Profile',
                  purpose: 'Everything about the person',
                  discussionQuestions: ['Should the phone be editable?'],
                },
              ],
            },
          ],
          supportedLocales: ['en', 'ru'],
        },
        currentPath: '/schedule',
        session: { isSignedIn: true, userIdentifier: '79990000002', isBusy: false },
        features: [],
        currentLocale: 'en',
      }),
      '{"dartwayStudioBridge":4,"type":"manifest","payload":{' +
        '"manifest":{"projectName":"Demo","zones":[{"label":"Client app","rootPath":"/schedule",' +
        '"access":"signedIn","screens":[{"path":"/schedule/profile","parentPath":"/schedule",' +
        '"title":"Profile","purpose":"Everything about the person",' +
        '"discussionQuestions":["Should the phone be editable?"]}]}],' +
        '"features":[],"supportedLocales":["en","ru"]},' +
        '"currentPath":"/schedule",' +
        '"session":{"isSignedIn":true,"userIdentifier":"79990000002","isBusy":false},' +
        '"features":[],"currentLocale":"en"}}',
    );
  });

  test('featuresChanged — empty passport lists are left out, as in Dart', () => {
    assert.equal(
      encodeStudioBridgeMessage({
        type: 'featuresChanged',
        path: '/schedule',
        features: [
          { id: 'schedule-list', title: 'List', behaviors: ['does a thing'], knownIssues: [] },
        ],
      }),
      '{"dartwayStudioBridge":4,"type":"featuresChanged","payload":{"path":"/schedule",' +
        '"features":[{"id":"schedule-list","title":"List","behaviors":["does a thing"]}]}}',
    );
  });

  test('routeChanged carries the route name only when there is one', () => {
    assert.equal(
      encodeStudioBridgeMessage({ type: 'routeChanged', path: '/auth' }),
      '{"dartwayStudioBridge":4,"type":"routeChanged","payload":{"path":"/auth"}}',
    );
    assert.equal(
      encodeStudioBridgeMessage({ type: 'routeChanged', path: '/ad/123', routeName: 'adDetail' }),
      '{"dartwayStudioBridge":4,"type":"routeChanged","payload":' +
        '{"path":"/ad/123","routeName":"adDetail"}}',
    );
  });

  test('sessionChanged', () => {
    assert.equal(
      encodeStudioBridgeMessage({
        type: 'sessionChanged',
        session: { isSignedIn: true, userIdentifier: '1', displayLabel: 'Anna', isBusy: true },
      }),
      '{"dartwayStudioBridge":4,"type":"sessionChanged","payload":{"session":' +
        '{"isSignedIn":true,"userIdentifier":"1","displayLabel":"Anna","isBusy":true}}}',
    );
  });

  test('localeChanged', () => {
    assert.equal(
      encodeStudioBridgeMessage({ type: 'localeChanged', locale: 'ru' }),
      '{"dartwayStudioBridge":4,"type":"localeChanged","payload":{"locale":"ru"}}',
    );
  });

  test('inspectPointResult, with a feature and without', () => {
    assert.equal(
      encodeStudioBridgeMessage({
        type: 'inspectPointResult',
        requestId: 'inspect-7',
        feature: { id: 'ad/card', title: 'Ad card' },
      }),
      '{"dartwayStudioBridge":4,"type":"inspectPointResult","payload":{"requestId":"inspect-7",' +
        '"feature":{"id":"ad/card","title":"Ad card"}}}',
    );
    assert.equal(
      encodeStudioBridgeMessage({ type: 'inspectPointResult', requestId: 'inspect-7' }),
      '{"dartwayStudioBridge":4,"type":"inspectPointResult","payload":{"requestId":"inspect-7"}}',
    );
  });
});

describe('decoding what Studio sends', () => {
  test('studioConnect carries the access token', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage(
        '{"dartwayStudioBridge":4,"type":"studioConnect","payload":{"accessToken":"abc"}}',
      ),
      { type: 'studioConnect', accessToken: 'abc' },
    );
  });

  test('a connect with no token decodes to an empty one', () => {
    // Which only a build in its zero-config local-dev mode accepts.
    assert.deepEqual(
      decodeStudioBridgeMessage('{"dartwayStudioBridge":4,"type":"studioConnect","payload":{}}'),
      { type: 'studioConnect', accessToken: '' },
    );
  });

  test('navigateRequest', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage(
        '{"dartwayStudioBridge":4,"type":"navigateRequest","payload":{"path":"/schedule"}}',
      ),
      { type: 'navigateRequest', path: '/schedule' },
    );
  });

  test('signInRequest carries the credentials', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage(
        '{"dartwayStudioBridge":4,"type":"signInRequest","payload":' +
          '{"identifier":"79990000002","secret":"123456"}}',
      ),
      { type: 'signInRequest', identifier: '79990000002', secret: '123456' },
    );
  });

  test('signOutRequest', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage('{"dartwayStudioBridge":4,"type":"signOutRequest","payload":{}}'),
      { type: 'signOutRequest' },
    );
  });

  test('localeRequest', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage(
        '{"dartwayStudioBridge":4,"type":"localeRequest","payload":{"locale":"ru"}}',
      ),
      { type: 'localeRequest', locale: 'ru' },
    );
  });

  test('inspectPointRequest carries the fractional point and the request id', () => {
    assert.deepEqual(
      decodeStudioBridgeMessage(
        '{"dartwayStudioBridge":4,"type":"inspectPointRequest","payload":' +
          '{"requestId":"inspect-7","horizontalFraction":0.25,"verticalFraction":0.75}}',
      ),
      {
        type: 'inspectPointRequest',
        requestId: 'inspect-7',
        horizontalFraction: 0.25,
        verticalFraction: 0.75,
      },
    );
  });

  test('a whole-number fraction written as an int, the way Dart may send it', () => {
    const message = decodeStudioBridgeMessage(
      '{"dartwayStudioBridge":4,"type":"inspectPointRequest","payload":' +
        '{"requestId":"i","horizontalFraction":1,"verticalFraction":0}}',
    );
    assert.equal(message?.type, 'inspectPointRequest');
    assert.deepEqual(message, {
      type: 'inspectPointRequest',
      requestId: 'i',
      horizontalFraction: 1,
      verticalFraction: 0,
    });
  });
});

describe('decoding rejects foreign and malformed input', () => {
  test('non-string data', () => {
    assert.equal(decodeStudioBridgeMessage(42), null);
    assert.equal(decodeStudioBridgeMessage(null), null);
    assert.equal(decodeStudioBridgeMessage({ type: 'appReady' }), null);
  });

  test('invalid json', () => {
    assert.equal(decodeStudioBridgeMessage('not json'), null);
  });

  test('json that is not an object', () => {
    assert.equal(decodeStudioBridgeMessage('[1,2,3]'), null);
    assert.equal(decodeStudioBridgeMessage('"hello"'), null);
  });

  test('missing or wrong envelope version', () => {
    assert.equal(decodeStudioBridgeMessage('{"type":"appReady"}'), null);
    assert.equal(decodeStudioBridgeMessage('{"dartwayStudioBridge":999,"type":"appReady"}'), null);
    // v1 (bilingual passports) is a different schema — must be ignored.
    assert.equal(decodeStudioBridgeMessage('{"dartwayStudioBridge":1,"type":"appReady"}'), null);
  });

  test('unknown message type', () => {
    assert.equal(
      decodeStudioBridgeMessage(
        `{"dartwayStudioBridge":${studioBridgeProtocol.version},"type":"bogus","payload":{}}`,
      ),
      null,
    );
  });

  test('a foreign postMessage is ignored', () => {
    // e.g. dev-server or browser-extension chatter on the same window.
    assert.equal(decodeStudioBridgeMessage('{"source":"react-devtools"}'), null);
  });
});

test('every message type survives a round trip', () => {
  const messages: StudioBridgeMessage[] = [
    { type: 'appReady' },
    { type: 'routeChanged', path: '/ad/1', routeName: 'adDetail' },
    { type: 'sessionChanged', session: { isSignedIn: true, userIdentifier: '1', isBusy: false } },
    {
      type: 'featuresChanged',
      path: '/schedule',
      features: [{ id: 'a', title: 'A', purpose: 'why', behaviors: ['b'] }],
    },
    { type: 'localeChanged', locale: 'ru' },
    { type: 'inspectPointResult', requestId: 'i', feature: { id: 'a', title: 'A' } },
    { type: 'studioConnect', accessToken: 'token' },
    { type: 'navigateRequest', path: '/x' },
    { type: 'signInRequest', identifier: 'a', secret: 'b' },
    { type: 'signOutRequest' },
    { type: 'localeRequest', locale: 'en' },
    { type: 'inspectPointRequest', requestId: 'i', horizontalFraction: 0.5, verticalFraction: 0.5 },
  ];

  for (const message of messages) {
    assert.deepEqual(
      decodeStudioBridgeMessage(encodeStudioBridgeMessage(message)),
      message,
      `round trip failed for ${message.type}`,
    );
  }
});
