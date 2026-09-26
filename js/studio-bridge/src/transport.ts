import { StudioHostPeer } from './host-peer.ts';
import {
  decodeStudioBridgeMessage,
  encodeStudioBridgeMessage,
  type StudioBridgeMessage,
} from './protocol/messages.ts';

/**
 * A two-way message pipe between an app and Studio. The shipped implementation
 * wraps `window.postMessage`; the host accepts any implementation, which is how
 * the handshake is tested without a browser.
 */
export interface StudioMessageChannel {
  /** Decoded messages from the other side. Returns an unsubscribe function. */
  subscribe(listener: (message: StudioBridgeMessage) => void): () => void;
  send(message: StudioBridgeMessage): void;
  dispose(): void;
}

/**
 * True when this page runs inside an iframe — the only context where attaching
 * can succeed. False during server-side rendering, where there is no window at
 * all.
 */
export function isEmbeddedInStudioFrame(): boolean {
  return typeof window !== 'undefined' && window.parent !== window;
}

/**
 * The app-side transport, or null when there is nothing to attach to.
 *
 * Origin note: the channel accepts only messages from the window that embeds
 * it — the parent frame, checked by identity of the window object rather than
 * by an origin string anybody can have — and pins its replies to the origin of
 * the first accepted message. See {@link StudioHostPeer}. Beyond that there is
 * no origin allowlist — an embedding page can only drive what the bridge
 * exposes, and what it may drive at all is decided by the access token, not by
 * the frame it sits in.
 */
export function createStudioHostChannel(): StudioMessageChannel | null {
  if (!isEmbeddedInStudioFrame()) return null;
  return new StudioHostWindowChannel();
}

class StudioHostWindowChannel implements StudioMessageChannel {
  #listeners = new Set<(message: StudioBridgeMessage) => void>();

  /** Who this channel listens to and answers — see {@link StudioHostPeer}. */
  #peer = new StudioHostPeer();

  #onWindowMessage = (event: MessageEvent): void => {
    const fromParent = event.source === window.parent;
    if (this.#peer.refuse({ fromParent, origin: event.origin }) !== null) return;
    if (typeof event.data !== 'string') return;
    const message = decodeStudioBridgeMessage(event.data);
    if (message === null) return;
    this.#peer.accepted(event.origin);
    for (const listener of this.#listeners) listener(message);
  };

  constructor() {
    window.addEventListener('message', this.#onWindowMessage);
  }

  subscribe(listener: (message: StudioBridgeMessage) => void): () => void {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  }

  send(message: StudioBridgeMessage): void {
    window.parent.postMessage(encodeStudioBridgeMessage(message), this.#peer.origin ?? '*');
  }

  dispose(): void {
    window.removeEventListener('message', this.#onWindowMessage);
    this.#listeners.clear();
  }
}
