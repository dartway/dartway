import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { StudioHostPeer } from '../src/host-peer.ts';

/**
 * An app in a frame hears every window message there is. This is how it tells
 * the Studio that embedded it from everything else. The twin of
 * `studio_host_peer_test.dart` in the Dart package — same rules, same cases.
 */
describe('StudioHostPeer', () => {
  test('answers nobody in particular until someone has spoken', () => {
    const peer = new StudioHostPeer();
    assert.equal(peer.origin, null);
  });

  test('a message from anything but the parent frame is refused, whatever its origin says', () => {
    const peer = new StudioHostPeer();
    assert.equal(
      peer.refuse({ fromParent: false, origin: 'https://studio.dartway.dev' }),
      'foreignSource',
    );
    assert.equal(peer.origin, null);
  });

  test('the parent is heard, and the first message it is believed on pins where the answers go', () => {
    const peer = new StudioHostPeer();
    assert.equal(peer.refuse({ fromParent: true, origin: 'https://studio.dartway.dev' }), null);
    peer.accepted('https://studio.dartway.dev');
    assert.equal(peer.origin, 'https://studio.dartway.dev');
  });

  test('once pinned, another origin is refused rather than followed — this is the manifest going to the wrong Studio', () => {
    const peer = new StudioHostPeer();
    peer.accepted('https://studio.dartway.dev');
    assert.equal(
      peer.refuse({ fromParent: true, origin: 'https://evil.example' }),
      'foreignOrigin',
    );
    assert.equal(peer.origin, 'https://studio.dartway.dev');
  });

  test('a nested preview cannot take the address over: the grandchild is not the parent', () => {
    const peer = new StudioHostPeer();
    peer.accepted('https://studio.dartway.dev');
    // The app embeds a preview of its own; that frame speaks from the same
    // origin as the real Studio and is still not the peer.
    assert.equal(
      peer.refuse({ fromParent: false, origin: 'https://studio.dartway.dev' }),
      'foreignSource',
    );
  });

  test('the pin is the first accepted message, not the last', () => {
    const peer = new StudioHostPeer();
    peer.accepted('https://studio.dartway.dev');
    peer.accepted('https://other.example');
    assert.equal(peer.origin, 'https://studio.dartway.dev');
  });
});
