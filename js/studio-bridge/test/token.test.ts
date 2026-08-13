import assert from 'node:assert/strict';
import { before, describe, test } from 'node:test';

import {
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
