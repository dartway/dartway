/**
 * Why a window message was not the peer's. Returned by {@link StudioHostPeer.refuse}.
 */
export type StudioHostPeerRefusal = 'foreignSource' | 'foreignOrigin';

/**
 * Who the app's side of the bridge listens to, and where it answers.
 *
 * The app runs inside a frame and hears every `message` event of its window:
 * from the Studio that embedded it, from a frame it embeds itself (Studio
 * inside a preview inside Studio is a normal day), and from any page that can
 * reach the window at all. Only one of those is the peer.
 *
 * Two rules, and both were once missing:
 *
 * - **the message comes from the parent frame**, checked by identity of the
 *   window object, not by its origin — an origin is a string anybody can
 *   have, and a grandchild frame on the same origin is not the peer;
 * - **the origin is pinned to the first accepted message.** Afterwards a
 *   message from another origin is refused rather than followed: the parent
 *   navigating elsewhere ends the session, it does not move it. Without the
 *   pin, anything that spoke between the token check and the manifest became
 *   the address the manifest — the passports of every screen — was sent to.
 *
 * A plain class with no DOM dependency, so it is tested directly rather than
 * through a browser channel — the same reason the Dart implementation
 * (`StudioHostPeer` in `dartway_studio_bridge`, whose rules this mirrors) sits
 * outside its web channel.
 */
export class StudioHostPeer {
  #origin: string | null = null;

  /**
   * The origin of the peer, once one has been accepted. Until then the app
   * answers `*`: the handshake has to start somewhere, and what it says (that
   * an app is here) is no secret.
   */
  get origin(): string | null {
    return this.#origin;
  }

  /** Why this window message is not the peer's, or null when it is. */
  refuse(options: { fromParent: boolean; origin: string }): StudioHostPeerRefusal | null {
    if (!options.fromParent) return 'foreignSource';
    const pinned = this.#origin;
    if (pinned !== null && options.origin !== pinned) return 'foreignOrigin';
    return null;
  }

  /**
   * Records that a bridge message from `origin` was accepted — the first one
   * pins it.
   */
  accepted(origin: string): void {
    this.#origin ??= origin;
  }
}
