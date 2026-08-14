import assert from 'node:assert/strict';
import { before, describe, test } from 'node:test';

import {
  looksLikeStudioBridgeToken,
  studioSignedAccessValidator,
  studioSigningPublicKey,
  verifyStudioBridgeToken,
} from '../src/index.ts';

/**
 * Studio's half of the contract, written out here rather than imported: the app
 * never signs, so the package ships no signer, and the issuer lives in another
 * repository. Keeping an independent implementation of the format in the test
 * is what makes the test worth having — it fails when the verifier drifts from
 * the format the docs promise, instead of drifting along with it.
 */
async function signToken({
  signingKey,
  origin,
  expiresAt,
}: {
  signingKey: CryptoKey;
  origin: string;
  expiresAt: Date;
}): Promise<string> {
  const payload = base64UrlSegment(
    new TextEncoder().encode(
      JSON.stringify({ origin, exp: Math.floor(expiresAt.getTime() / 1000) }),
    ),
  );
  const signature = await crypto.subtle.sign(
    { name: 'Ed25519' },
    signingKey,
    new TextEncoder().encode(payload),
  );
  return `${payload}.${base64UrlSegment(new Uint8Array(signature))}`;
}

function base64UrlSegment(bytes: Uint8Array): string {
  return base64(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function base64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function newStudioKeyPair(): Promise<CryptoKeyPair> {
  return (await crypto.subtle.generateKey({ name: 'Ed25519' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
}

async function publicKeyOf(pair: CryptoKeyPair): Promise<string> {
  return base64(new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey)));
}

const appOrigin = 'https://app.example.com';
const inTenMinutes = (): Date => new Date(Date.now() + 10 * 60 * 1000);

let studioKeyPair: CryptoKeyPair;
let studioPublicKey: string;
let validToken: string;

before(async () => {
  studioKeyPair = await newStudioKeyPair();
  studioPublicKey = await publicKeyOf(studioKeyPair);
  validToken = await signToken({
    signingKey: studioKeyPair.privateKey,
    origin: appOrigin,
    expiresAt: inTenMinutes(),
  });
});

test('the shipped signing key is a 32-byte Ed25519 public key', () => {
  assert.equal(atob(studioSigningPublicKey).length, 32);
});

describe('verifyStudioBridgeToken', () => {
  test('accepts a live token signed for this origin', async () => {
    assert.equal(
      await verifyStudioBridgeToken(validToken, { appOrigin, publicKey: studioPublicKey }),
      true,
    );
  });

  test('accepts the same origin written differently', async () => {
    assert.equal(
      await verifyStudioBridgeToken(validToken, {
        appOrigin: 'https://App.Example.com/',
        publicKey: studioPublicKey,
      }),
      true,
    );
  });

  test('rejects a token issued for another origin', async () => {
    const foreignToken = await signToken({
      signingKey: studioKeyPair.privateKey,
      origin: 'https://someone-else.example.com',
      expiresAt: inTenMinutes(),
    });
    assert.equal(
      await verifyStudioBridgeToken(foreignToken, { appOrigin, publicKey: studioPublicKey }),
      false,
    );
  });

  test('rejects an expired token', async () => {
    const expiredToken = await signToken({
      signingKey: studioKeyPair.privateKey,
      origin: appOrigin,
      expiresAt: new Date(Date.now() - 1000),
    });
    assert.equal(
      await verifyStudioBridgeToken(expiredToken, { appOrigin, publicKey: studioPublicKey }),
      false,
    );
  });

  test('rejects a token that expires exactly now', async () => {
    const now = new Date();
    const token = await signToken({
      signingKey: studioKeyPair.privateKey,
      origin: appOrigin,
      expiresAt: now,
    });
    assert.equal(
      await verifyStudioBridgeToken(token, { appOrigin, publicKey: studioPublicKey, now }),
      false,
    );
  });

  test('rejects a token whose claims were edited after signing', async () => {
    const forgedPayload = base64UrlSegment(
      new TextEncoder().encode(
        JSON.stringify({
          origin: appOrigin,
          exp: Math.floor(Date.now() / 1000) + 365 * 24 * 3600,
        }),
      ),
    );
    const forgedToken = `${forgedPayload}.${validToken.split('.')[1]}`;
    assert.equal(
      await verifyStudioBridgeToken(forgedToken, { appOrigin, publicKey: studioPublicKey }),
      false,
    );
  });

  test('rejects a token signed by another key', async () => {
    const impostorToken = await signToken({
      signingKey: (await newStudioKeyPair()).privateKey,
      origin: appOrigin,
      expiresAt: inTenMinutes(),
    });
    assert.equal(
      await verifyStudioBridgeToken(impostorToken, { appOrigin, publicKey: studioPublicKey }),
      false,
    );
  });

  test('rejects garbage instead of throwing', async () => {
    for (const malformed of ['', 'not-a-token', 'a.b.c', 'aGk=.###', '.', 'eyJ9.']) {
      assert.equal(
        await verifyStudioBridgeToken(malformed, { appOrigin, publicKey: studioPublicKey }),
        false,
        `accepted ${malformed}`,
      );
    }
  });

  test('a build that names no origin verifies nothing', async () => {
    assert.equal(
      await verifyStudioBridgeToken(validToken, { appOrigin: '', publicKey: studioPublicKey }),
      false,
    );
  });
});

describe('when the token cannot be checked at all', () => {
  test('no WebCrypto on the page — refuses, and says which context it needs', async () => {
    const console = captureConsole();
    const platform = usePlatform(undefined);
    try {
      assert.equal(
        await verifyStudioBridgeToken(validToken, { appOrigin, publicKey: studioPublicKey }),
        false,
      );
    } finally {
      platform.restore();
      console.restore();
    }
    assert.equal(console.messages.length, 1);
    assert.match(console.messages[0] ?? '', /secure context/);
  });

  test('a browser without Ed25519 — refuses, and names the browsers that have it', async () => {
    const console = captureConsole();
    const platform = usePlatform({
      importKey: () => {
        throw new Error('Unrecognized algorithm name');
      },
    });
    try {
      assert.equal(
        await verifyStudioBridgeToken(validToken, { appOrigin, publicKey: studioPublicKey }),
        false,
      );
    } finally {
      platform.restore();
      console.restore();
    }
    assert.equal(console.messages.length, 1);
    assert.match(console.messages[0] ?? '', /cannot verify Ed25519/);
  });

  test('a misconfigured public key is named as such, and named once', async () => {
    const sixteenBytes = base64(new Uint8Array(16));
    const console = captureConsole();
    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        assert.equal(
          await verifyStudioBridgeToken(validToken, { appOrigin, publicKey: sixteenBytes }),
          false,
        );
      }
    } finally {
      console.restore();
    }
    // Studio retries its handshake every couple of seconds; a message per retry
    // would bury itself.
    assert.equal(console.messages.length, 1);
    assert.match(console.messages[0] ?? '', /16 bytes, not the 32/);
  });

  test('an ordinary forged token is refused without a word', async () => {
    const console = captureConsole();
    try {
      const forged = `${validToken.split('.')[0]}.${base64UrlSegment(new Uint8Array(64))}`;
      assert.equal(
        await verifyStudioBridgeToken(forged, { appOrigin, publicKey: studioPublicKey }),
        false,
      );
      assert.equal(
        await verifyStudioBridgeToken('not-a-token', { appOrigin, publicKey: studioPublicKey }),
        false,
      );
    } finally {
      console.restore();
    }
    // Refusing a bad token is the function working, not something to report.
    assert.deepEqual(console.messages, []);
  });
});

/** Swaps in a platform whose WebCrypto behaves as the test needs. */
function usePlatform(subtle: unknown): { restore: () => void } {
  const original = Object.getOwnPropertyDescriptor(globalThis, 'crypto');
  Object.defineProperty(globalThis, 'crypto', {
    value: subtle === undefined ? undefined : { subtle },
    configurable: true,
    writable: true,
  });
  return {
    restore: () => {
      if (original === undefined) delete (globalThis as { crypto?: unknown }).crypto;
      else Object.defineProperty(globalThis, 'crypto', original);
    },
  };
}

function captureConsole(): { messages: string[]; restore: () => void } {
  const original = globalThis.console.error;
  const messages: string[] = [];
  globalThis.console.error = (...args: unknown[]) => {
    messages.push(args.map((arg) => String(arg)).join(' '));
  };
  return {
    messages,
    restore: () => {
      globalThis.console.error = original;
    },
  };
}

describe('looksLikeStudioBridgeToken', () => {
  test('recognises the shape of a real token', () => {
    assert.equal(looksLikeStudioBridgeToken(validToken), true);
  });

  test('recognises an expired, foreign or forged one just the same — shape is all it reads', async () => {
    const expired = await signToken({
      signingKey: studioKeyPair.privateKey,
      origin: 'https://someone-else.example.com',
      expiresAt: new Date(Date.now() - 24 * 3600 * 1000),
    });
    assert.equal(looksLikeStudioBridgeToken(expired), true);
    assert.equal(
      await verifyStudioBridgeToken(expired, { appOrigin, publicKey: studioPublicKey }),
      false,
      'shape must never be mistaken for validity',
    );
  });

  test('turns down anything that is not a token', () => {
    const notTokens = [
      '', // nothing presented at all
      'not-a-token', // no segments
      'a.b.c', // three of them
      'aGk=.###', // a segment that is not base64url
      'not.atoken', // two segments, neither one base64url json
      'e30.AAAA', // a payload that parses, claiming nothing
      '.AAAA', // an empty payload segment
      'eyJvcmlnaW4iOiJodHRwczovL2EuYiJ9.AAAA', // origin, no expiry
    ];
    for (const value of notTokens) {
      assert.equal(looksLikeStudioBridgeToken(value), false, `took "${value}" for a token`);
    }
  });
});

describe('studioSignedAccessValidator', () => {
  test('lets a valid token in and keeps everything else out', async () => {
    const validator = studioSignedAccessValidator(appOrigin, { publicKey: studioPublicKey });
    assert.equal(await validator(validToken), true);
    assert.equal(await validator('forged'), false);
    assert.equal(await validator(''), false);
  });

  test("rejects a token not signed by the key this build trusts", async () => {
    const validator = studioSignedAccessValidator(appOrigin);
    assert.equal(await validator(validToken), false);
  });

  test('a build with no origin named accepts any connection (local dev)', async () => {
    const validator = studioSignedAccessValidator('');
    assert.equal(await validator(''), true);
    assert.equal(await validator('anything at all'), true);
  });
});
