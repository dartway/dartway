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
 * Origin note: the channel accepts the first valid bridge message from the
 * embedding window and pins that origin for its replies. There is no origin
 * allowlist — an embedding page can only drive what the bridge exposes, and
 * what it may drive at all is decided by the access token, not by the frame it
 * sits in.
 */
export function createStudioHostChannel(): StudioMessageChannel | null {
  if (!isEmbeddedInStudioFrame()) return null;
  return new StudioHostWindowChannel();
}

class StudioHostWindowChannel implements StudioMessageChannel {
  #listeners = new Set<(message: StudioBridgeMessage) => void>();

  /** Studio's origin once the first valid bridge message arrives; targeted
   * replies go there instead of `*`. */
  #peerOrigin: string | null = null;

  #onWindowMessage = (event: MessageEvent): void => {
    if (typeof event.data !== 'string') return;
    const message = decodeStudioBridgeMessage(event.data);
    if (message === null) return;
    this.#peerOrigin = event.origin;
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
    window.parent.postMessage(encodeStudioBridgeMessage(message), this.#peerOrigin ?? '*');
  }

  dispose(): void {
    window.removeEventListener('message', this.#onWindowMessage);
    this.#listeners.clear();
  }
}
