import {
  asJson,
  featureFromJson,
  featureListFromJson,
  featureToJson,
  manifestFromJson,
  manifestToJson,
  sessionFromJson,
  sessionToJson,
  type StudioFeatureInfo,
  type StudioProjectManifest,
  type StudioSessionState,
} from '../models.ts';
import { studioBridgeProtocol } from './protocol.ts';

// --- app → Studio -----------------------------------------------------------

/** Announced on host attach (page load, reload). */
export interface AppReadyMessage {
  type: typeof studioBridgeProtocol.appReady;
}

/**
 * The handshake was heard and refused — the token presented in
 * `studioConnect` parsed as a signed Studio token and did not pass the app's
 * check (expired, or signed by another key).
 *
 * It carries no reason. Which of the two it was is Studio's to work out from
 * the token it issued itself, and an app that spelled it out would be telling
 * whoever asked how to get closer.
 *
 * **Only a token that parses gets an answer.** An empty, absent or garbled
 * token is still met with silence, so a stranger who guessed the preview's URL
 * does not learn that there is a bridge here at all.
 *
 * **This type was added without bumping the protocol version, on purpose**
 * (see `studioBridgeProtocol.version`). An app built before it exists simply
 * never sends it, and a probe reads that as "no answer" — exactly what it read
 * before this message existed. Do not bump the version to "fix" this: that
 * would cut off every build in the field in both directions.
 */
export interface ConnectRefusedMessage {
  type: typeof studioBridgeProtocol.connectRefused;
}

/**
 * The handshake response — the full manifest plus the current route, session,
 * features and locale, so Studio renders correctly right away.
 */
export interface ManifestMessage {
  type: typeof studioBridgeProtocol.manifest;
  manifest: StudioProjectManifest;
  currentPath: string;
  session: StudioSessionState;
  /** Features mounted on the current screen at connect time. */
  features: StudioFeatureInfo[];
  /** Active UI locale, empty when the app is not localized. */
  currentLocale: string;
}

/**
 * The app's router moved to a new location. `path` is the concrete location
 * (`/ad/123`); `routeName` is the stable route identity (`adDetail`) — screen
 * attribution binds to the name, the path is the instance context.
 */
export interface RouteChangedMessage {
  type: typeof studioBridgeProtocol.routeChanged;
  path: string;
  routeName?: string;
}

/** The session changed (sign-in, sign-out, switch in progress). */
export interface SessionChangedMessage {
  type: typeof studioBridgeProtocol.sessionChanged;
  session: StudioSessionState;
}

/** The features declared on the current screen changed. */
export interface FeaturesChangedMessage {
  type: typeof studioBridgeProtocol.featuresChanged;
  path: string;
  features: StudioFeatureInfo[];
}

/** The app's UI locale changed. */
export interface LocaleChangedMessage {
  type: typeof studioBridgeProtocol.localeChanged;
  locale: string;
}

/**
 * The answer to an inspect-point request — the feature at that point, or none
 * when nothing declared covers it.
 */
export interface InspectPointResultMessage {
  type: typeof studioBridgeProtocol.inspectPointResult;
  /** Echoed back untouched, so a late answer cannot resolve a newer request. */
  requestId: string;
  feature?: StudioFeatureInfo;
}

// --- Studio → app -----------------------------------------------------------

/**
 * Connection request; the app answers with a manifest message only if it
 * accepts `accessToken`. Sent on Studio start, retried while unconnected, and
 * re-sent whenever an app-ready message arrives.
 */
export interface StudioConnectMessage {
  type: typeof studioBridgeProtocol.studioConnect;
  accessToken: string;
}

/** Navigate the live app to the given route path. */
export interface NavigateRequestMessage {
  type: typeof studioBridgeProtocol.navigateRequest;
  path: string;
}

/**
 * Sign in with the given test credentials through the app's regular auth flow.
 * The credentials belong to Studio's project config — the app itself ships no
 * test users and no special sign-in path.
 */
export interface SignInRequestMessage {
  type: typeof studioBridgeProtocol.signInRequest;
  /** The user identifier in the form the app's auth expects (phone, email). */
  identifier: string;
  /** A test verification code for OTP flows, a password for password flows. */
  secret: string;
}

/** Sign the current user out. */
export interface SignOutRequestMessage {
  type: typeof studioBridgeProtocol.signOutRequest;
}

/** Switch the app UI to a language tag from the manifest's supportedLocales. */
export interface LocaleRequestMessage {
  type: typeof studioBridgeProtocol.localeRequest;
  locale: string;
}

/**
 * What feature, if any, is at this point on screen — the "pencil" flow's
 * tap-to-inspect. The point is given as *fractions* of the app's own viewport
 * (0.0 top/left, 1.0 bottom/right), not pixels: Studio may be showing the
 * preview scaled or letterboxed, but a fraction of the viewport means the same
 * point regardless of how it is currently displayed.
 */
export interface InspectPointRequestMessage {
  type: typeof studioBridgeProtocol.inspectPointRequest;
  /** Ties this request to the one answer that belongs to it; opaque to the app. */
  requestId: string;
  horizontalFraction: number;
  verticalFraction: number;
}

export type StudioBridgeMessage =
  | AppReadyMessage
  | ConnectRefusedMessage
  | ManifestMessage
  | RouteChangedMessage
  | SessionChangedMessage
  | FeaturesChangedMessage
  | LocaleChangedMessage
  | InspectPointResultMessage
  | StudioConnectMessage
  | NavigateRequestMessage
  | SignInRequestMessage
  | SignOutRequestMessage
  | LocaleRequestMessage
  | InspectPointRequestMessage;

/**
 * The payload of a message, with keys in the same order the Dart
 * implementation writes them — so two encoders of one protocol produce the
 * same string, and a golden-string test means something.
 */
function payloadToJson(message: StudioBridgeMessage): Record<string, unknown> {
  switch (message.type) {
    case studioBridgeProtocol.appReady:
    case studioBridgeProtocol.connectRefused:
    case studioBridgeProtocol.signOutRequest:
      return {};
    case studioBridgeProtocol.manifest:
      return {
        manifest: manifestToJson(message.manifest),
        currentPath: message.currentPath,
        session: sessionToJson(message.session),
        features: message.features.map(featureToJson),
        currentLocale: message.currentLocale,
      };
    case studioBridgeProtocol.routeChanged:
      return message.routeName != null
        ? { path: message.path, routeName: message.routeName }
        : { path: message.path };
    case studioBridgeProtocol.sessionChanged:
      return { session: sessionToJson(message.session) };
    case studioBridgeProtocol.featuresChanged:
      return { path: message.path, features: message.features.map(featureToJson) };
    case studioBridgeProtocol.localeChanged:
    case studioBridgeProtocol.localeRequest:
      return { locale: message.locale };
    case studioBridgeProtocol.inspectPointResult:
      return message.feature != null
        ? { requestId: message.requestId, feature: featureToJson(message.feature) }
        : { requestId: message.requestId };
    case studioBridgeProtocol.studioConnect:
      return { accessToken: message.accessToken };
    case studioBridgeProtocol.navigateRequest:
      return { path: message.path };
    case studioBridgeProtocol.signInRequest:
      return { identifier: message.identifier, secret: message.secret };
    case studioBridgeProtocol.inspectPointRequest:
      return {
        requestId: message.requestId,
        horizontalFraction: message.horizontalFraction,
        verticalFraction: message.verticalFraction,
      };
  }
}

/** Encodes a message into the string that travels over `postMessage`. */
export function encodeStudioBridgeMessage(message: StudioBridgeMessage): string {
  return JSON.stringify({
    [studioBridgeProtocol.envelopeKey]: studioBridgeProtocol.version,
    [studioBridgeProtocol.typeKey]: message.type,
    [studioBridgeProtocol.payloadKey]: payloadToJson(message),
  });
}

/**
 * Parses raw `postMessage` data; null for anything that is not a valid message
 * of the supported protocol version — foreign messages are common on `window`
 * (dev tooling, browser extensions, other frames) and must be ignored
 * silently.
 */
/**
 * The envelope version inside raw postMessage `data`, or null when there is no
 * envelope — the data is not ours at all.
 *
 * This is the one thing decoding cannot tell you. A message that fails to
 * decode fails the same way whether it belongs to somebody else or is our own
 * envelope at another version, and the two are opposite diagnoses: ignore the
 * first, repair the second. An app on v3 and a Studio on v4 were simply quiet
 * at each other for a day because nothing said which.
 *
 * Accepts either the raw string off the wire or an already-parsed object, so a
 * caller that has parsed the JSON does not parse it twice. The twin of
 * `StudioBridgeProtocol.envelopeVersionOf` in the Dart package.
 */
export function studioBridgeEnvelopeVersion(data: unknown): number | null {
  let decoded: unknown = data;
  if (typeof data === 'string') {
    try {
      decoded = JSON.parse(data);
    } catch {
      return null;
    }
  }
  if (typeof decoded !== 'object' || decoded === null || Array.isArray(decoded)) return null;
  const version = (decoded as Record<string, unknown>)[studioBridgeProtocol.envelopeKey];
  return typeof version === 'number' ? version : null;
}

export function decodeStudioBridgeMessage(data: unknown): StudioBridgeMessage | null {
  if (typeof data !== 'string') return null;
  let decoded: unknown;
  try {
    decoded = JSON.parse(data);
  } catch {
    return null;
  }
  if (typeof decoded !== 'object' || decoded === null || Array.isArray(decoded)) return null;

  const envelope = decoded as Record<string, unknown>;
  // Read through `studioBridgeEnvelopeVersion` rather than the key directly:
  // the version check and the diagnostic that explains a drop have to agree
  // about what an envelope is, and two readings of it would not.
  if (studioBridgeEnvelopeVersion(envelope) !== studioBridgeProtocol.version) return null;

  const payload = asJson(envelope[studioBridgeProtocol.payloadKey]);
  const string = (value: unknown, fallback = ''): string =>
    typeof value === 'string' ? value : fallback;
  const fraction = (value: unknown): number => (typeof value === 'number' ? value : 0);

  switch (envelope[studioBridgeProtocol.typeKey]) {
    case studioBridgeProtocol.appReady:
      return { type: studioBridgeProtocol.appReady };
    case studioBridgeProtocol.connectRefused:
      return { type: studioBridgeProtocol.connectRefused };
    case studioBridgeProtocol.manifest:
      return {
        type: studioBridgeProtocol.manifest,
        manifest: manifestFromJson(asJson(payload.manifest)),
        currentPath: string(payload.currentPath, '/'),
        session: sessionFromJson(asJson(payload.session)),
        features: featureListFromJson(payload.features),
        currentLocale: string(payload.currentLocale),
      };
    case studioBridgeProtocol.routeChanged: {
      const message: RouteChangedMessage = {
        type: studioBridgeProtocol.routeChanged,
        path: string(payload.path, '/'),
      };
      if (typeof payload.routeName === 'string') message.routeName = payload.routeName;
      return message;
    }
    case studioBridgeProtocol.sessionChanged:
      return {
        type: studioBridgeProtocol.sessionChanged,
        session: sessionFromJson(asJson(payload.session)),
      };
    case studioBridgeProtocol.featuresChanged:
      return {
        type: studioBridgeProtocol.featuresChanged,
        path: string(payload.path, '/'),
        features: featureListFromJson(payload.features),
      };
    case studioBridgeProtocol.localeChanged:
      return { type: studioBridgeProtocol.localeChanged, locale: string(payload.locale) };
    case studioBridgeProtocol.inspectPointResult: {
      const message: InspectPointResultMessage = {
        type: studioBridgeProtocol.inspectPointResult,
        requestId: string(payload.requestId),
      };
      if (
        typeof payload.feature === 'object' &&
        payload.feature !== null &&
        !Array.isArray(payload.feature)
      ) {
        message.feature = featureFromJson(payload.feature as Record<string, unknown>);
      }
      return message;
    }
    case studioBridgeProtocol.studioConnect:
      return {
        type: studioBridgeProtocol.studioConnect,
        accessToken: string(payload.accessToken),
      };
    case studioBridgeProtocol.navigateRequest:
      return { type: studioBridgeProtocol.navigateRequest, path: string(payload.path, '/') };
    case studioBridgeProtocol.signInRequest:
      return {
        type: studioBridgeProtocol.signInRequest,
        identifier: string(payload.identifier),
        secret: string(payload.secret),
      };
    case studioBridgeProtocol.signOutRequest:
      return { type: studioBridgeProtocol.signOutRequest };
    case studioBridgeProtocol.localeRequest:
      return { type: studioBridgeProtocol.localeRequest, locale: string(payload.locale) };
    case studioBridgeProtocol.inspectPointRequest:
      return {
        type: studioBridgeProtocol.inspectPointRequest,
        requestId: string(payload.requestId),
        horizontalFraction: fraction(payload.horizontalFraction),
        verticalFraction: fraction(payload.verticalFraction),
      };
    default:
      return null;
  }
}
