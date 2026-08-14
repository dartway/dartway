/**
 * The public half of the key pair DartWay Studio signs bridge access tokens
 * with: base64 of the 32 raw Ed25519 public-key bytes.
 *
 * It ships inside this package deliberately. A public key only *checks*
 * signatures — it cannot make them — so it is harmless in the open, and it is
 * the same for every project, which is the whole point: a team connecting its
 * app to Studio has nothing to copy out of Studio, nothing to keep secret and
 * nothing to replace when the pair is rotated. They update this package.
 *
 * The same constant, byte for byte, ships in the Dart package.
 */
export const studioSigningPublicKey = 'gpXp+7p3BGDYFMvR2JHaBYuT1DaRsKhVeIBSgye44LM=';

/** Separates a token's payload from its signature. */
const tokenSegmentSeparator = '.';

export interface VerifyStudioBridgeTokenOptions {
  /** This app's own public address. An empty one matches nothing. */
  appOrigin: string;
  /** Defaults to {@link studioSigningPublicKey}. */
  publicKey?: string | undefined;
  /** Defaults to the current time. */
  now?: Date | undefined;
}

/**
 * Verifies an access token presented by a connecting Studio.
 *
 * **The wire format** — two base64url segments, unpadded, joined by a dot:
 *
 * ```text
 * <payload>.<signature>
 * payload   = base64url( utf8( {"origin":"https://app.example","exp":1765540000} ) )
 * signature = base64url( ed25519_sign( privateKey, ascii(payload) ) )
 * ```
 *
 * `origin` is the address the token is good for and `exp` is its expiry in
 * whole seconds since the Unix epoch. The signature covers the payload
 * **segment as written**, not the JSON it decodes to: whoever signs and whoever
 * verifies then agree byte for byte without having to agree on how a map is
 * serialised.
 *
 * Resolves true only when all four hold: the token parses, its signature checks
 * out against `publicKey`, its `origin` is `appOrigin`, and its `exp` is still
 * ahead of `now`. Anything else — a malformed token, a foreign origin, an
 * expired one, one signed by another key — resolves false rather than throwing:
 * a connection is refused the same way whatever is wrong with it, and the app
 * carries on running.
 *
 * Origins are compared as scheme, host and port, so case and a trailing slash
 * do not matter. An empty `appOrigin` matches nothing — an app that names no
 * address of its own is not deciding here whether to accept the connection; see
 * {@link studioSignedAccessValidator}, which is where that decision lives.
 *
 * **Requires Ed25519 in the platform's WebCrypto** (Chrome 137+, Safari 17+,
 * Firefox 130+, Node 18.4+) and a secure context — https or localhost. Where it
 * is missing, verification fails closed: the app refuses the connection instead
 * of trusting an unchecked token, and says why once in the console — a refusal
 * is otherwise silence, and silence is what a browser too old to check looks
 * like from Studio's side as well.
 */
export async function verifyStudioBridgeToken(
  accessToken: string,
  { appOrigin, publicKey = studioSigningPublicKey, now }: VerifyStudioBridgeTokenOptions,
): Promise<boolean> {
  const expectedOrigin = normalizedOrigin(appOrigin);
  if (expectedOrigin === '') return false;

  const segments = accessToken.split(tokenSegmentSeparator);
  if (segments.length !== 2) return false;
  const [payloadSegment, signatureSegment] = segments as [string, string];

  let claims: Record<string, unknown>;
  let signature: Uint8Array<ArrayBuffer>;
  let publicKeyBytes: Uint8Array<ArrayBuffer>;
  try {
    const parsed: unknown = JSON.parse(new TextDecoder().decode(decodeSegment(payloadSegment)));
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return false;
    claims = parsed as Record<string, unknown>;
    signature = decodeSegment(signatureSegment);
    publicKeyBytes = decodeBase64(publicKey);
  } catch {
    return false;
  }

  if (normalizedOrigin(claims.origin) !== expectedOrigin) return false;

  const expiresAtSeconds = claims.exp;
  if (typeof expiresAtSeconds !== 'number' || !Number.isInteger(expiresAtSeconds)) return false;
  if (expiresAtSeconds * 1000 <= (now ?? new Date()).getTime()) return false;

  const subtle = globalThis.crypto?.subtle;
  if (subtle === undefined) {
    reportOnce(
      'WebCrypto is unavailable on this page. `crypto.subtle` exists only in a ' +
        'secure context, so serve the app over https (localhost counts).',
    );
    return false;
  }

  let key: CryptoKey;
  try {
    key = await subtle.importKey('raw', publicKeyBytes, { name: 'Ed25519' }, false, ['verify']);
  } catch (error) {
    // A 32-byte key that the platform still refuses to import is the platform
    // saying it does not do Ed25519; any other length is this build's own
    // `publicKey` being wrong. Both are worth saying out loud — see below.
    reportOnce(
      publicKeyBytes.length === 32
        ? 'this browser cannot verify Ed25519 signatures with WebCrypto. It needs ' +
            'Chrome 137+, Safari 17+ or Firefox 130+.'
        : `the configured publicKey is ${publicKeyBytes.length} bytes, not the 32 ` +
            'an Ed25519 public key has. Leave it unset to use the key shipped with ' +
            'this package.',
      error,
    );
    return false;
  }

  try {
    return await subtle.verify(
      { name: 'Ed25519' },
      key,
      signature,
      new TextEncoder().encode(payloadSegment),
    );
  } catch {
    // A signature of the wrong shape. Ordinary traffic, not a diagnosis:
    // refusing it is the function working, and saying so on every retry would
    // bury the messages above.
    return false;
  }
}

/**
 * Said once per page, and only when the token could not be *checked* at all —
 * as opposed to being checked and refused, which is this function's day job and
 * says nothing about the app.
 *
 * The failure it describes is otherwise mute: the app simply does not answer
 * the handshake, Studio shows "not connected", and nothing anywhere points at
 * the cause. A refusal stays a refusal — nothing here weakens the check — but
 * whoever is looking at the console learns why.
 */
function reportOnce(reason: string, error?: unknown): void {
  if (reported.has(reason)) return;
  reported.add(reason);
  console.error(
    `[dartway/studio-bridge] Studio's access token could not be checked: ${reason} ` +
      'The connection is refused rather than trusted. For local development, leave ' +
      '`appOrigin` unset — that mode verifies nothing and needs none of this.',
    ...(error === undefined ? [] : [error]),
  );
}

const reported = new Set<string>();

/**
 * Whether `accessToken` is *shaped* like a token Studio signs — two base64url
 * segments, the first of which decodes to a JSON object carrying an `origin`
 * string and an integer `exp`. Nothing here is checked against a key, an origin
 * or a clock: a forged token passes this and is still refused by
 * {@link verifyStudioBridgeToken}.
 *
 * It exists to separate two refusals that are otherwise one. A token that
 * parses came from something that knows the format — in practice, from Studio —
 * so refusing it is worth *saying* (`connectRefused`): whoever sent it can be
 * told their signature is stale rather than left to guess whether the bridge is
 * there at all. Anything that does not parse is met with silence, so a stranger
 * who guessed the preview's URL learns nothing.
 *
 * A stranger who bothers to construct a well-formed token does learn that this
 * page carries a bridge. That is the price of the diagnosis, it is bounded —
 * nothing else crosses the bridge without a valid signature — and it was chosen
 * deliberately over leaving a misconfigured Studio with no way to tell "the app
 * has no bridge" from "the app rejected my key".
 */
export function looksLikeStudioBridgeToken(accessToken: string): boolean {
  const segments = accessToken.split(tokenSegmentSeparator);
  if (segments.length !== 2 || segments.some((segment) => segment === '')) return false;
  try {
    const claims: unknown = JSON.parse(
      new TextDecoder().decode(decodeSegment(segments[0] as string)),
    );
    decodeSegment(segments[1] as string);
    if (typeof claims !== 'object' || claims === null || Array.isArray(claims)) return false;
    const { origin, exp } = claims as Record<string, unknown>;
    return typeof origin === 'string' && typeof exp === 'number' && Number.isInteger(exp);
  } catch {
    return false;
  }
}

export interface StudioSignedAccessOptions {
  /**
   * Exists for tests and for the day an app has to trust a Studio running on
   * someone else's servers; a normal build leaves it alone.
   */
  publicKey?: string | undefined;
}

/**
 * The access-token check the bridge host runs: accept a connecting Studio only
 * when it presents a token issued for `appOrigin` — this app's own public
 * address — and signed by Studio's key.
 *
 * A stolen token is therefore worthless anywhere but here, which is the
 * property the whole scheme exists for.
 *
 * **An empty `appOrigin` accepts any connection.** That is the zero-config
 * local-dev mode: a build that was never told what address it answers at lets a
 * Studio on the same machine drive it without anyone issuing keys. A deployed
 * build names its address and from then on only a signed token gets in.
 */
export function studioSignedAccessValidator(
  appOrigin: string,
  { publicKey = studioSigningPublicKey }: StudioSignedAccessOptions = {},
): (accessToken: string) => Promise<boolean> {
  return async (accessToken) =>
    appOrigin.trim() === '' ||
    (await verifyStudioBridgeToken(accessToken, { appOrigin, publicKey }));
}

/** Decodes one unpadded base64url segment, restoring the padding `atob` wants. */
function decodeSegment(segment: string): Uint8Array<ArrayBuffer> {
  return decodeBase64(segment.replaceAll('-', '+').replaceAll('_', '/'));
}

function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const padded = value.padEnd(Math.ceil(value.length / 4) * 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Scheme, host and port of an address, so that `https://App.Example/` and
 * `https://app.example` are the same origin. Anything that is not an http(s)
 * URL with a host compares as itself — which is what makes a garbage `origin`
 * claim fail against a real `appOrigin` rather than parse into something.
 */
function normalizedOrigin(address: unknown): string {
  if (typeof address !== 'string') return '';
  const trimmed = address.trim();
  if (trimmed === '') return '';
  try {
    const url = new URL(trimmed);
    if ((url.protocol !== 'http:' && url.protocol !== 'https:') || url.host === '') {
      return trimmed;
    }
    return url.origin;
  } catch {
    return trimmed;
  }
}
