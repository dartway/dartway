import assert from 'node:assert/strict';
import { before, describe, test } from 'node:test';

import {
  attachStudioBridge,
  decodeStudioBridgeMessage,
  encodeStudioBridgeMessage,
  StudioFeatureRegistry,
  type StudioBridgeMessage,
  type StudioMessageChannel,
  type StudioProjectManifest,
} from '../src/index.ts';

/**
 * Studio, as far as the app can tell: everything crosses this channel as the
 * same wire string `postMessage` would carry, so the tests exercise the real
 * encoder and decoder rather than a shortcut around them.
 */
class FakeStudio implements StudioMessageChannel {
  readonly wire: string[] = [];
  disposed = false;
  #listeners = new Set<(message: StudioBridgeMessage) => void>();

  subscribe(listener: (message: StudioBridgeMessage) => void): () => void {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  }

  send(message: StudioBridgeMessage): void {
    this.wire.push(encodeStudioBridgeMessage(message));
  }

  dispose(): void {
    this.disposed = true;
    this.#listeners.clear();
  }

  /** Studio speaks. */
  say(message: StudioBridgeMessage): void {
    const delivered = decodeStudioBridgeMessage(encodeStudioBridgeMessage(message));
    assert.notEqual(delivered, null);
    for (const listener of [...this.#listeners]) listener(delivered as StudioBridgeMessage);
  }

  get heard(): StudioBridgeMessage[] {
    return this.wire.map((raw) => decodeStudioBridgeMessage(raw) as StudioBridgeMessage);
  }

  of<T extends StudioBridgeMessage['type']>(
    type: T,
  ): Extract<StudioBridgeMessage, { type: T }>[] {
    return this.heard.filter((message) => message.type === type) as Extract<
      StudioBridgeMessage,
      { type: T }
    >[];
  }
}

const manifest: StudioProjectManifest = {
  projectName: 'Demo',
  zones: [
    {
      label: 'Client app',
      rootPath: '/schedule',
      access: 'signedIn',
      screens: [{ path: '/schedule', title: 'Schedule', purpose: 'The week ahead' }],
    },
  ],
  supportedLocales: ['en', 'ru'],
};

const appOrigin = 'https://app.example.com';

async function waitFor(condition: () => boolean, what: string): Promise<void> {
  for (let attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  assert.fail(`timed out waiting for ${what}`);
}

/** Long enough for anything the host was going to do to have happened. */
async function settle(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 60));
}

// --- Studio's half of the token contract, as in token.test.ts ---------------

let studioKeyPair: CryptoKeyPair;
let studioPublicKey: string;

before(async () => {
  studioKeyPair = (await crypto.subtle.generateKey({ name: 'Ed25519' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  studioPublicKey = base64(
    new Uint8Array(await crypto.subtle.exportKey('raw', studioKeyPair.publicKey)),
  );
});

async function tokenFor(origin: string, expiresAt: Date): Promise<string> {
  const payload = base64(
    new TextEncoder().encode(
      JSON.stringify({ origin, exp: Math.floor(expiresAt.getTime() / 1000) }),
    ),
  )
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
  const signature = await crypto.subtle.sign(
    { name: 'Ed25519' },
    studioKeyPair.privateKey,
    new TextEncoder().encode(payload),
  );
  return `${payload}.${base64(new Uint8Array(signature))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')}`;
}

function base64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

describe('the handshake', () => {
  test('the app announces itself the moment it attaches', () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({ manifest, transport: studio });
    assert.notEqual(host, null);
    assert.deepEqual(studio.heard, [{ type: 'appReady' }]);
    host?.detach();
  });

  test('a token signed for this origin gets the manifest', async () => {
    const studio = new FakeStudio();
    const features = new StudioFeatureRegistry();
    features.declare({ id: 'schedule/session-list', title: 'Session list' });

    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      features,
      transport: studio,
      currentPath: () => '/schedule',
      currentSession: () => ({ isSignedIn: true, userIdentifier: '79990000002' }),
      currentLocale: () => 'ru',
    });

    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor(appOrigin, new Date(Date.now() + 600_000)),
    });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    const answer = studio.of('manifest')[0];
    assert.equal(answer?.manifest.projectName, 'Demo');
    assert.equal(answer?.currentPath, '/schedule');
    assert.equal(answer?.session.userIdentifier, '79990000002');
    assert.equal(answer?.currentLocale, 'ru');
    assert.deepEqual(answer?.features.map((feature) => feature.id), ['schedule/session-list']);
    assert.equal(host?.isConnected, true);
    host?.detach();
  });

  test('a token issued for someone else gets no manifest', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      transport: studio,
    });

    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor('https://someone-else.example.com', new Date(Date.now() + 600_000)),
    });
    await settle();

    assert.deepEqual(studio.of('manifest'), []);
    assert.equal(host?.isConnected, false);
    host?.detach();
  });

  test('an expired token gets no manifest', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      transport: studio,
    });

    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor(appOrigin, new Date(Date.now() - 1000)),
    });
    await settle();

    assert.deepEqual(studio.of('manifest'), []);
    assert.equal(host?.isConnected, false);
    host?.detach();
  });

  test('a refused token is told so — Studio signs correctly, so a refusal it can read means its signature is stale', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      transport: studio,
    });

    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor(appOrigin, new Date(Date.now() - 1000)),
    });
    await waitFor(() => studio.of('connectRefused').length === 1, 'the refusal');

    // Being answered is not being let in.
    assert.equal(host?.isConnected, false);
    studio.say({ type: 'navigateRequest', path: '/admin' });
    await settle();
    assert.deepEqual(studio.of('manifest'), []);
    host?.detach();
  });

  test('anything that is not a token is met with silence, so a stranger who guessed the URL learns nothing', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      transport: studio,
    });

    for (const accessToken of ['', 'forged', 'not.atoken', 'e30.AAAA']) {
      studio.say({ type: 'studioConnect', accessToken });
    }
    await settle();

    assert.deepEqual(studio.heard, [{ type: 'appReady' }]);
    assert.equal(host?.isConnected, false);
    host?.detach();
  });

  test('the zero-config mode refuses nobody, so it answers no refusals', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({ manifest, transport: studio });

    studio.say({ type: 'studioConnect', accessToken: 'not.atoken' });
    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor('https://someone-else.example.com', new Date(Date.now() - 1000)),
    });
    await waitFor(() => studio.of('manifest').length === 2, 'the manifests');

    assert.deepEqual(studio.of('connectRefused'), []);
    host?.detach();
  });

  test('a build that names no origin connects without a token (local dev)', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({ manifest, transport: studio });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    assert.equal(host?.isConnected, true);
    host?.detach();
  });
});

describe('commands', () => {
  test('are refused until the handshake has been accepted', async () => {
    const studio = new FakeStudio();
    const navigated: string[] = [];
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      transport: studio,
      onNavigate: (path) => navigated.push(path),
    });

    studio.say({ type: 'navigateRequest', path: '/admin' });
    await settle();
    assert.deepEqual(navigated, [], 'drove the app without presenting a token');

    studio.say({
      type: 'studioConnect',
      accessToken: await tokenFor(appOrigin, new Date(Date.now() + 600_000)),
    });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    studio.say({ type: 'navigateRequest', path: '/schedule' });
    assert.deepEqual(navigated, ['/schedule']);
    host?.detach();
  });

  test('reach the app once it is connected', async () => {
    const studio = new FakeStudio();
    const done: string[] = [];
    const host = attachStudioBridge({
      manifest,
      transport: studio,
      onSignIn: (identifier, secret) => {
        done.push(`signIn:${identifier}:${secret}`);
      },
      onSignOut: () => {
        done.push('signOut');
      },
      onLocale: (locale) => done.push(`locale:${locale}`),
    });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    studio.say({ type: 'signInRequest', identifier: '79990000002', secret: '123456' });
    studio.say({ type: 'signOutRequest' });
    studio.say({ type: 'localeRequest', locale: 'ru' });

    assert.deepEqual(done, ['signIn:79990000002:123456', 'signOut', 'locale:ru']);
    host?.detach();
  });

  test('an inspect request is always answered, with the id it came with', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({ manifest, transport: studio });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    // Nothing is declared with an element here, and there is no document to hit
    // test against — the point is that silence is never the answer, since
    // Studio cannot tell it apart from an app that predates the message.
    studio.say({
      type: 'inspectPointRequest',
      requestId: 'inspect-7',
      horizontalFraction: 0.5,
      verticalFraction: 0.5,
    });

    assert.deepEqual(studio.of('inspectPointResult'), [
      { type: 'inspectPointResult', requestId: 'inspect-7' },
    ]);
    host?.detach();
  });
});

describe('reporting the current screen', () => {
  test('a feature declared after connecting is reported for the current path', async () => {
    const studio = new FakeStudio();
    const features = new StudioFeatureRegistry();
    let path = '/schedule';
    const host = attachStudioBridge({
      manifest,
      features,
      transport: studio,
      currentPath: () => path,
    });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');
    assert.deepEqual(studio.of('manifest')[0]?.features, []);

    const listed = features.declare({
      id: 'schedule/session-list',
      title: 'Session list',
      purpose: 'Lets a client find a class and book it',
      behaviors: ['Shows the coming week'],
      knownIssues: ['Cancelled sessions still take a slot'],
    });
    const booking = features.declare({ id: 'schedule/booking', title: 'Booking' });

    await waitFor(() => studio.of('featuresChanged').length === 1, 'the feature report');
    const report = studio.of('featuresChanged')[0];
    assert.equal(report?.path, '/schedule');
    assert.deepEqual(
      report?.features.map((feature) => feature.id),
      ['schedule/session-list', 'schedule/booking'],
    );
    assert.deepEqual(report?.features[0]?.knownIssues, ['Cancelled sessions still take a slot']);

    // Leaving the screen withdraws what it declared.
    path = '/admin';
    listed.release();
    booking.release();
    await waitFor(() => studio.of('featuresChanged').length === 2, 'the second feature report');
    assert.deepEqual(studio.of('featuresChanged')[1], {
      type: 'featuresChanged',
      path: '/admin',
      features: [],
    });

    host?.detach();
  });

  test('the same screen is not reported twice over', async () => {
    const studio = new FakeStudio();
    const features = new StudioFeatureRegistry();
    const host = attachStudioBridge({
      manifest,
      features,
      transport: studio,
      currentPath: () => '/schedule',
    });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    const handle = features.declare({ id: 'a', title: 'A' });
    await waitFor(() => studio.of('featuresChanged').length === 1, 'the feature report');

    // A re-render that re-declares the very same passport says nothing new.
    handle.update({ id: 'a', title: 'A' });
    host?.reportFeatures();
    await settle();
    assert.equal(studio.of('featuresChanged').length, 1);

    handle.update({ id: 'a', title: 'A', purpose: 'why it exists' });
    await waitFor(() => studio.of('featuresChanged').length === 2, 'the updated passport');

    host?.detach();
  });

  test('route, session and locale changes reach a connected Studio', async () => {
    const studio = new FakeStudio();
    const host = attachStudioBridge({
      manifest,
      transport: studio,
      currentPath: () => '/schedule',
    });

    studio.say({ type: 'studioConnect', accessToken: '' });
    await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

    host?.reportRoute('/ad/123', 'adDetail');
    host?.reportSession({ isSignedIn: true, displayLabel: 'Anna' });
    host?.reportLocale('ru');

    assert.deepEqual(studio.of('routeChanged'), [
      { type: 'routeChanged', path: '/ad/123', routeName: 'adDetail' },
    ]);
    assert.equal(studio.of('sessionChanged')[0]?.session.displayLabel, 'Anna');
    assert.deepEqual(studio.of('localeChanged'), [{ type: 'localeChanged', locale: 'ru' }]);

    host?.detach();
  });

  test('nothing is reported before a Studio has been let in', async () => {
    const studio = new FakeStudio();
    const features = new StudioFeatureRegistry();
    const host = attachStudioBridge({
      manifest,
      appOrigin,
      publicKey: studioPublicKey,
      features,
      transport: studio,
      currentPath: () => '/schedule',
    });

    features.declare({ id: 'a', title: 'A' });
    host?.reportRoute('/ad/123');
    host?.reportSession({ isSignedIn: true });
    host?.reportLocale('ru');
    await settle();

    assert.deepEqual(studio.heard, [{ type: 'appReady' }]);
    host?.detach();
  });
});

test('detaching ends it', async () => {
  const studio = new FakeStudio();
  const features = new StudioFeatureRegistry();
  const host = attachStudioBridge({
    manifest,
    features,
    transport: studio,
    currentPath: () => '/schedule',
  });

  studio.say({ type: 'studioConnect', accessToken: '' });
  await waitFor(() => studio.of('manifest').length === 1, 'the manifest');

  host?.detach();
  assert.equal(studio.disposed, true);
  assert.equal(host?.isConnected, false);

  const before = studio.wire.length;
  features.declare({ id: 'a', title: 'A' });
  await settle();
  assert.equal(studio.wire.length, before, 'kept talking after detaching');
});
