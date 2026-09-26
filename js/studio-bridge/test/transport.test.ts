import assert from 'node:assert/strict';
import { afterEach, describe, test } from 'node:test';

/**
 * `StudioHostWindowChannel` (in `src/transport.ts`) is the one piece of the
 * bridge that talks to a real `window` — everything else in this package is
 * tested through the `StudioMessageChannel` interface with a fake transport,
 * which never exercises the peer check at all. This file stands a minimal
 * `window` up instead, so the check that only the embedding parent frame is
 * heard runs against the real class, not a description of it.
 *
 * Node has no `Window`, so `MessagePort` stands in for "a window" wherever
 * identity is what matters: `MessageEvent.source` only accepts a
 * `MessagePort` (or null) here, and two distinct ports are two distinct peers
 * exactly as two distinct windows would be.
 */

class FakeWindow extends EventTarget {
  parent: FakeWindow | MessagePort = this;
}

function silencedPort(): MessagePort {
  const { port1 } = new MessageChannel();
  // Real code would call `postMessage(data, origin)`; the MessagePort version
  // takes a transfer list instead. Captured calls only need the arguments, not
  // a working transport.
  const calls: unknown[][] = [];
  (port1 as unknown as { postMessage: (...args: unknown[]) => void }).postMessage = (
    ...args: unknown[]
  ) => {
    calls.push(args);
  };
  (port1 as unknown as { calls: unknown[][] }).calls = calls;
  return port1;
}

let originalWindow: unknown;

afterEach(() => {
  if (originalWindow === undefined) {
    delete (globalThis as Record<string, unknown>).window;
  } else {
    (globalThis as Record<string, unknown>).window = originalWindow;
  }
});

async function withFakeWindow<T>(
  run: (app: FakeWindow, studioParent: MessagePort) => Promise<T> | T,
): Promise<T> {
  originalWindow = (globalThis as Record<string, unknown>).window;
  const app = new FakeWindow();
  const studioParent = silencedPort();
  app.parent = studioParent;
  (globalThis as Record<string, unknown>).window = app;
  return run(app, studioParent);
}

describe('StudioHostWindowChannel (the real window transport)', () => {
  test('a message from the parent frame is heard', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();
      assert.notEqual(channel, null);

      const received: unknown[] = [];
      channel?.subscribe((message) => received.push(message));

      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          origin: 'https://studio.dartway.dev',
          source: studioParent,
        }),
      );

      assert.deepEqual(received, [{ type: 'studioConnect', accessToken: '' }]);
      channel?.dispose();
    });
  });

  test('a message from a window that is not the parent is ignored, whatever its origin', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();
      const received: unknown[] = [];
      channel?.subscribe((message) => received.push(message));

      const impostor = silencedPort();
      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          // The genuine Studio origin, but from a different window — a sibling
          // or child frame on the same origin is still not the peer.
          origin: 'https://studio.dartway.dev',
          source: impostor,
        }),
      );

      assert.deepEqual(received, []);
      channel?.dispose();
      void studioParent;
    });
  });

  test('once an origin is pinned, a later message from the parent at another origin is ignored', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();
      const received: unknown[] = [];
      channel?.subscribe((message) => received.push(message));

      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          origin: 'https://studio.dartway.dev',
          source: studioParent,
        }),
      );
      assert.equal(received.length, 1);

      // The parent's own window is unchanged (still `source === studioParent`),
      // but the origin it now claims does not match the one that was pinned —
      // as if the parent had navigated to another origin mid-session.
      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'navigateRequest', path: '/admin' }),
          origin: 'https://evil.example',
          source: studioParent,
        }),
      );

      assert.equal(received.length, 1, 'a message at a foreign origin must not be delivered');
      channel?.dispose();
    });
  });

  test('a non-bridge message from the parent does not pin its origin — only a decoded one does', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();
      const received: unknown[] = [];
      channel?.subscribe((message) => received.push(message));

      // The parent frame is free to postMessage things this bridge does not
      // speak (its own app logic, another library sharing the page) — coming
      // from the real parent is not enough on its own to become the peer.
      // If pinning ever moved ahead of the decode check, this message's
      // origin would win the race instead of the one that actually spoke the
      // protocol.
      app.dispatchEvent(
        new MessageEvent('message', {
          data: 'not a bridge message at all',
          origin: 'https://origin-b.example',
          source: studioParent,
        }),
      );
      assert.deepEqual(received, []);

      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          origin: 'https://origin-a.example',
          source: studioParent,
        }),
      );
      assert.equal(received.length, 1);

      channel?.send({ type: 'appReady' });
      const calls = (studioParent as unknown as { calls: unknown[][] }).calls;
      assert.equal(calls.length, 1);
      assert.equal(calls[0]?.[1], 'https://origin-a.example', 'pinned to A, not the earlier B');

      // And now that A is pinned, a later message claiming to be B (still
      // from the same real parent window) is refused, exactly like the
      // "once an origin is pinned" case above — B never got a chance to pin
      // anything in the first place.
      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'navigateRequest', path: '/admin' }),
          origin: 'https://origin-b.example',
          source: studioParent,
        }),
      );
      assert.equal(received.length, 1);

      channel?.dispose();
    });
  });

  test('replies are pinned to the first accepted origin, not sent to "*"', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();

      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          origin: 'https://studio.dartway.dev',
          source: studioParent,
        }),
      );

      channel?.send({ type: 'appReady' });

      const calls = (studioParent as unknown as { calls: unknown[][] }).calls;
      assert.equal(calls.length, 1);
      assert.equal(calls[0]?.[1], 'https://studio.dartway.dev');
      channel?.dispose();
    });
  });

  test('disposing stops listening', async () => {
    await withFakeWindow(async (app, studioParent) => {
      const { createStudioHostChannel } = await import('../src/transport.ts');
      const { encodeStudioBridgeMessage } = await import('../src/protocol/messages.ts');
      const channel = createStudioHostChannel();
      const received: unknown[] = [];
      channel?.subscribe((message) => received.push(message));
      channel?.dispose();

      app.dispatchEvent(
        new MessageEvent('message', {
          data: encodeStudioBridgeMessage({ type: 'studioConnect', accessToken: '' }),
          origin: 'https://studio.dartway.dev',
          source: studioParent,
        }),
      );

      assert.deepEqual(received, []);
    });
  });
});
