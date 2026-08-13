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
 * of trusting an unchecked token.
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
  if (subtle === undefined) return false;
  try {
    const key = await subtle.importKey('raw', publicKeyBytes, { name: 'Ed25519' }, false, [
      'verify',
    ]);
    return await subtle.verify(
      { name: 'Ed25519' },
      key,
      signature,
      new TextEncoder().encode(payloadSegment),
    );
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
