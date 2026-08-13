/**
 * The app side of the DartWay Studio bridge, for JavaScript apps.
 *
 * One core, two thin wrappers: `@dartway/studio-bridge/react` and
 * `@dartway/studio-bridge/vue` only make declaring a feature idiomatic — the
 * protocol, the handshake and the access check live here, in one place, so the
 * two framework wrappers cannot drift apart from each other or from the Dart
 * implementation of the same protocol.
 */

export {
  signedOutSession,
  type StudioFeatureInfo,
  type StudioProjectManifest,
  type StudioScreenSpec,
  type StudioSessionState,
  type StudioZoneAccess,
  type StudioZoneSpec,
} from './models.ts';

export { studioBridgeProtocol } from './protocol/protocol.ts';

export {
  decodeStudioBridgeMessage,
  encodeStudioBridgeMessage,
  type AppReadyMessage,
  type FeaturesChangedMessage,
  type InspectPointRequestMessage,
  type InspectPointResultMessage,
  type LocaleChangedMessage,
  type LocaleRequestMessage,
  type ManifestMessage,
  type NavigateRequestMessage,
  type RouteChangedMessage,
  type SessionChangedMessage,
  type SignInRequestMessage,
  type SignOutRequestMessage,
  type StudioBridgeMessage,
  type StudioConnectMessage,
} from './protocol/messages.ts';

export {
  studioSignedAccessValidator,
  studioSigningPublicKey,
  verifyStudioBridgeToken,
  type StudioSignedAccessOptions,
  type VerifyStudioBridgeTokenOptions,
} from './access/token.ts';

export {
  declareStudioFeature,
  studioFeatures,
  StudioFeatureRegistry,
  type StudioFeatureElement,
  type StudioFeatureHandle,
  type StudioFeatureViewport,
} from './features.ts';

export {
  createStudioHostChannel,
  isEmbeddedInStudioFrame,
  type StudioMessageChannel,
} from './transport.ts';

export {
  attachStudioBridge,
  getStudioBridge,
  type StudioBridgeConfig,
  type StudioBridgeHost,
} from './host.ts';
