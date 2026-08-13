import {
  studioFeatures,
  type StudioFeatureElement,
  type StudioFeatureHandle,
  type StudioFeatureRegistry,
} from './features.ts';
import {
  signedOutSession,
  type StudioFeatureInfo,
  type StudioProjectManifest,
  type StudioSessionState,
} from './models.ts';
import { studioBridgeProtocol } from './protocol/protocol.ts';
import type { StudioBridgeMessage } from './protocol/messages.ts';
import { studioSignedAccessValidator } from './access/token.ts';
import { createStudioHostChannel, type StudioMessageChannel } from './transport.ts';

export interface StudioBridgeConfig {
  /** What the app declares about itself: zones, screen passports, locales. */
  manifest: StudioProjectManifest;

  /**
   * This app's own public address, e.g. `https://preview.example.com`. Studio
   * is let in only when it presents a token signed for exactly this origin.
   *
   * **Left out (or empty) the app accepts any connection** — the zero-config
   * local-dev mode, so that Studio on your laptop previews your dev server
   * without anyone issuing keys. Name the origin on every deployed build.
   */
  appOrigin?: string | undefined;

  /**
   * The key that checks Studio's signature. Defaults to the one shipped in this
   * package; override for tests, or for a Studio on someone else's servers.
   */
  publicKey?: string | undefined;

  /** Defaults to the browser location (hash included, for hash routers). */
  currentPath?: (() => string) | undefined;

  /** Defaults to a signed-out session. */
  currentSession?: (() => StudioSessionState) | undefined;

  /** Active UI locale; omit when the app is not localized. */
  currentLocale?: (() => string) | undefined;

  /** Studio asks the app to navigate — run it through your own router. */
  onNavigate?: ((path: string) => void) | undefined;

  /**
   * Studio asks the app to sign in with test credentials from its project
   * config. Run them through your **regular** auth flow, exactly as if the user
   * had typed them: `secret` is a test verification code for OTP flows, a
   * password for password flows. The app ships no test users of its own.
   */
  onSignIn?: ((identifier: string, secret: string) => void | Promise<void>) | undefined;

  onSignOut?: (() => void | Promise<void>) | undefined;

  /** Studio asks for a locale from the manifest's `supportedLocales`. */
  onLocale?: ((locale: string) => void) | undefined;

  /**
   * Report route changes by watching `history` and `popstate` (default true).
   * Turn it off to call `reportRoute` from your router instead — which is what
   * you want if your routes have stable names worth sending.
   */
  autoTrackRoute?: boolean | undefined;

  /** Defaults to the shared registry the framework wrappers declare into. */
  features?: StudioFeatureRegistry | undefined;

  /**
   * The message pipe. Defaults to `postMessage` towards the embedding window;
   * supply one to test the handshake, or to embed the app some other way.
   */
  transport?: StudioMessageChannel | undefined;
}

export interface StudioBridgeHost {
  /** True once Studio has presented an accepted token. */
  readonly isConnected: boolean;

  /**
   * The app moved to a new location. `routeName` is the stable route identity
   * (`adDetail`) where the path (`/ad/123`) is the instance context.
   */
  reportRoute(path: string, routeName?: string): void;

  reportSession(session: StudioSessionState): void;

  reportLocale(locale: string): void;

  /**
   * Sends the current screen's features now. Called for you whenever a
   * declaration changes; reach for it after rendering something the registry
   * cannot see change.
   */
  reportFeatures(): void;

  /**
   * Declares a feature on the current screen — the same as
   * `declareStudioFeature`, reachable from the host for code that already holds
   * one.
   */
  declareFeature(
    feature: StudioFeatureInfo,
    element?: StudioFeatureElement | null,
  ): StudioFeatureHandle;

  detach(): void;
}

let activeHost: StudioBridgeHost | null = null;

/**
 * Attaches the app side of the Studio bridge, or returns null when there is
 * nothing to attach to — the app is not running inside an iframe. Callers keep
 * the app fully functional on null: outside Studio the bridge simply is not
 * there, and declaring features stays free.
 *
 * Call it once, as early as your app starts. Attaching again replaces the
 * previous host (a module reload during development does exactly that).
 */
export function attachStudioBridge(config: StudioBridgeConfig): StudioBridgeHost | null {
  const transport = config.transport ?? createStudioHostChannel();
  if (transport === null) return null;

  activeHost?.detach();
  activeHost = new StudioBridgeHostImpl(config, transport);
  return activeHost;
}

/** The attached host, or null outside Studio. */
export function getStudioBridge(): StudioBridgeHost | null {
  return activeHost;
}

class StudioBridgeHostImpl implements StudioBridgeHost {
  #config: StudioBridgeConfig;
  #channel: StudioMessageChannel;
  #features: StudioFeatureRegistry;
  #validateAccessToken: (accessToken: string) => Promise<boolean>;
  #unsubscribe: (() => void)[] = [];
  #connected = false;
  #detached = false;
  #featureReportScheduled = false;
  #lastFeatureReport: string | null = null;
  #lastTrackedPath: string | null = null;

  constructor(config: StudioBridgeConfig, channel: StudioMessageChannel) {
    this.#config = config;
    this.#channel = channel;
    this.#features = config.features ?? studioFeatures;
    this.#validateAccessToken = studioSignedAccessValidator(config.appOrigin ?? '', {
      publicKey: config.publicKey,
    });

    this.#unsubscribe.push(channel.subscribe((message) => this.#onMessage(message)));
    this.#unsubscribe.push(this.#features.subscribe(() => this.#scheduleFeatureReport()));
    if (config.autoTrackRoute ?? true) {
      this.#lastTrackedPath = this.#currentPath();
      this.#unsubscribe.push(trackBrowserRoute(() => this.#onBrowserRoute()));
    }

    channel.send({ type: studioBridgeProtocol.appReady });
  }

  get isConnected(): boolean {
    return this.#connected;
  }

  #onMessage(message: StudioBridgeMessage): void {
    if (message.type === studioBridgeProtocol.studioConnect) {
      // Answer the handshake only if the token is accepted; on refusal stay
      // silent — the app keeps running, Studio shows "not connected".
      void this.#validateAccessToken(message.accessToken).then((accepted) => {
        if (!accepted || this.#detached) return;
        this.#connected = true;
        this.#channel.send({
          type: studioBridgeProtocol.manifest,
          manifest: this.#config.manifest,
          currentPath: this.#currentPath(),
          session: this.#currentSession(),
          features: this.#features.list(),
          currentLocale: this.#config.currentLocale?.() ?? '',
        });
      });
      return;
    }

    // Every command is gated on the handshake, not just the manifest —
    // otherwise an embedding page could walk the app through its screens, or
    // sign it in, without presenting anything.
    if (!this.#connected) return;

    switch (message.type) {
      case studioBridgeProtocol.navigateRequest:
        this.#config.onNavigate?.(message.path);
        return;
      case studioBridgeProtocol.signInRequest:
        void this.#config.onSignIn?.(message.identifier, message.secret);
        return;
      case studioBridgeProtocol.signOutRequest:
        void this.#config.onSignOut?.();
        return;
      case studioBridgeProtocol.localeRequest:
        this.#config.onLocale?.(message.locale);
        return;
      case studioBridgeProtocol.inspectPointRequest:
        this.#answerInspectPoint(
          message.requestId,
          message.horizontalFraction,
          message.verticalFraction,
        );
        return;
      default:
        return; // App → Studio messages echoed back are ignored.
    }
  }

  /**
   * Answers an inspect request — and answers it even when the hit test throws.
   * Staying silent is indistinguishable from an app that predates the message,
   * so Studio would sit out its whole timeout and report a crash as "nothing
   * declared here".
   */
  #answerInspectPoint(
    requestId: string,
    horizontalFraction: number,
    verticalFraction: number,
  ): void {
    let feature: StudioFeatureInfo | null = null;
    try {
      feature = this.#features.featureAt(horizontalFraction, verticalFraction);
    } catch (error) {
      console.error('[dartway/studio-bridge] inspect-point request failed', error);
    }
    this.#channel.send(
      feature === null
        ? { type: studioBridgeProtocol.inspectPointResult, requestId }
        : { type: studioBridgeProtocol.inspectPointResult, requestId, feature },
    );
  }

  reportRoute(path: string, routeName?: string): void {
    this.#lastTrackedPath = path;
    if (!this.#connected) return;
    this.#channel.send(
      routeName === undefined
        ? { type: studioBridgeProtocol.routeChanged, path }
        : { type: studioBridgeProtocol.routeChanged, path, routeName },
    );
    this.#scheduleFeatureReport();
  }

  reportSession(session: StudioSessionState): void {
    if (!this.#connected) return;
    this.#channel.send({ type: studioBridgeProtocol.sessionChanged, session });
  }

  reportLocale(locale: string): void {
    if (!this.#connected) return;
    this.#channel.send({ type: studioBridgeProtocol.localeChanged, locale });
  }

  reportFeatures(): void {
    this.#featureReportScheduled = false;
    if (!this.#connected) return;
    const path = this.#currentPath();
    const features = this.#features.list();
    // The same list for the same screen twice says nothing new; a re-render
    // that touches every declaration would otherwise flood the channel.
    const signature = JSON.stringify([path, features]);
    if (signature === this.#lastFeatureReport) return;
    this.#lastFeatureReport = signature;
    this.#channel.send({ type: studioBridgeProtocol.featuresChanged, path, features });
  }

  declareFeature(
    feature: StudioFeatureInfo,
    element: StudioFeatureElement | null = null,
  ): StudioFeatureHandle {
    return this.#features.declare(feature, element);
  }

  detach(): void {
    this.#detached = true;
    this.#connected = false;
    for (const unsubscribe of this.#unsubscribe) unsubscribe();
    this.#unsubscribe = [];
    this.#channel.dispose();
    if (activeHost === this) activeHost = null;
  }

  #currentPath(): string {
    return this.#config.currentPath?.() ?? defaultCurrentPath();
  }

  #currentSession(): StudioSessionState {
    return this.#config.currentSession?.() ?? signedOutSession;
  }

  #onBrowserRoute(): void {
    const path = this.#currentPath();
    if (path === this.#lastTrackedPath) return;
    this.reportRoute(path);
  }

  /**
   * Features are reported one frame later on purpose: a route change fires
   * before the new screen's components mount, so reporting in the same turn
   * would describe the screen just left.
   */
  #scheduleFeatureReport(): void {
    if (this.#featureReportScheduled || this.#detached) return;
    this.#featureReportScheduled = true;
    const flush = (): void => {
      if (!this.#featureReportScheduled || this.#detached) return;
      this.reportFeatures();
    };
    if (typeof requestAnimationFrame === 'function') requestAnimationFrame(flush);
    else queueMicrotask(flush);
  }
}

/** The location as a route path — the hash for hash routers, the path otherwise. */
function defaultCurrentPath(): string {
  if (typeof window === 'undefined') return '/';
  const { hash, pathname } = window.location;
  return hash.startsWith('#/') ? hash.slice(1) : pathname;
}

/**
 * Watches the browser's own navigation, whatever router sits on top of it:
 * `pushState`/`replaceState` are wrapped (routers call them and fire no event
 * of their own) and back/forward and hash changes are listened for.
 *
 * Only ever installed inside a Studio frame — a standalone build of the app
 * never has its history touched.
 */
function trackBrowserRoute(onChange: () => void): () => void {
  if (typeof window === 'undefined' || typeof history === 'undefined') return () => {};

  const original = { pushState: history.pushState, replaceState: history.replaceState };
  for (const name of ['pushState', 'replaceState'] as const) {
    const wrapped = original[name];
    history[name] = function (this: History, ...args: Parameters<History['pushState']>) {
      const result = wrapped.apply(this, args);
      onChange();
      return result;
    };
  }
  window.addEventListener('popstate', onChange);
  window.addEventListener('hashchange', onChange);

  return () => {
    history.pushState = original.pushState;
    history.replaceState = original.replaceState;
    window.removeEventListener('popstate', onChange);
    window.removeEventListener('hashchange', onChange);
  };
}
