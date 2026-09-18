"""Makes the tokens `test/fixtures/provider_tokens.dart` holds.

Every token here is really signed: a key pair is made with `openssl`, the
claims are signed with it, and the public half is published as the JWKS the
tests give the verifier. The private keys stay in the temporary directory this
writes into and are never committed — a fixture the tests can re-sign at will
would let a mistake in the verifier hide behind a test that signs around it.

    python3 tool/make_provider_tokens.py > test/fixtures/provider_tokens.dart
"""

import base64, json, os, subprocess, tempfile


def b64u(raw):
    return base64.urlsafe_b64encode(raw).decode().rstrip('=')


def run(command, stdin=None):
    return subprocess.run(
        command, shell=True, input=stdin, capture_output=True, check=True
    ).stdout


def der_to_raw(der):
    """An openssl ECDSA signature (DER) as the 64 bytes JWS carries."""
    assert der[0] == 0x30
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b''
    for _ in range(2):
        assert der[index] == 0x02
        length = der[index + 1]
        value = der[index + 2 : index + 2 + length]
        index += 2 + length
        out += value.lstrip(b'\x00').rjust(32, b'\x00')
    return out


def sign(header, claims, key, elliptic):
    signing = (
        b64u(json.dumps(header, separators=(',', ':')).encode())
        + '.'
        + b64u(json.dumps(claims, separators=(',', ':')).encode())
    )
    der = run(f'openssl dgst -sha256 -sign {key}', signing.encode())
    return signing + '.' + b64u(der_to_raw(der) if elliptic else der)


def dart_map(value, indent):
    pad = ' ' * indent
    lines = ''.join(f"{pad}  '{k}': '{v}',\n" for k, v in value.items())
    return '{\n' + lines + pad + '}'


def main():
    work = tempfile.mkdtemp(prefix='dw_provider_tokens_')
    # The key a project downloads from Apple as a `.p8` and signs its client
    # secret with. Unlike the others, its private half is kept: the tests sign
    # with it and check the result against `openssl`.
    secret_key = os.path.join(work, 'secret.p8')
    rsa = os.path.join(work, 'rsa.pem')
    ec = os.path.join(work, 'ec.pem')
    run(f'openssl genrsa -out {rsa} 2048 2>/dev/null')
    run(f'openssl ecparam -genkey -name prime256v1 -noout -out {ec} 2>/dev/null')

    run(
        f'openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 '
        f'-pkeyopt ec_param_enc:named_curve -out {secret_key} 2>/dev/null'
    )
    secret_pem = open(secret_key).read().strip()
    secret_text = run(
        f'openssl ec -in {secret_key} -pubout -text -noout 2>/dev/null'
    ).decode()
    secret_point = bytes.fromhex(
        ''.join(secret_text.split('pub:')[1].split('ASN1 OID')[0].split()).replace(':', '')
    )
    secret_jwk = {
        'kty': 'EC',
        'kid': 'secret-1',
        'use': 'sig',
        'alg': 'ES256',
        'crv': 'P-256',
        'x': b64u(secret_point[1:33]),
        'y': b64u(secret_point[33:]),
    }

    modulus = (
        run(f'openssl rsa -in {rsa} -noout -modulus 2>/dev/null')
        .decode()
        .strip()
        .split('=')[1]
    )
    rsa_jwk = {
        'kty': 'RSA',
        'kid': 'rsa-1',
        'use': 'sig',
        'alg': 'RS256',
        'n': b64u(bytes.fromhex(modulus)),
        'e': b64u((65537).to_bytes(3, 'big')),
    }

    text = run(f'openssl ec -in {ec} -pubout -text -noout 2>/dev/null').decode()
    point = bytes.fromhex(
        ''.join(text.split('pub:')[1].split('ASN1 OID')[0].split()).replace(':', '')
    )
    assert point[0] == 4 and len(point) == 65
    ec_jwk = {
        'kty': 'EC',
        'kid': 'ec-1',
        'use': 'sig',
        'alg': 'ES256',
        'crv': 'P-256',
        'x': b64u(point[1:33]),
        'y': b64u(point[33:]),
    }

    # sha256 of "a-raw-nonce", which is what Apple's flow puts in the token
    # when the app sends that nonce.
    hashed_nonce = run('printf a-raw-nonce | openssl dgst -sha256 -r').decode().split()[0]

    apple_header = {'alg': 'ES256', 'kid': 'ec-1', 'typ': 'JWT'}
    apple = {
        'iss': 'https://appleid.apple.com',
        'sub': '000123.abc',
        'aud': 'com.club.app',
        'exp': 2000000000,
        'iat': 1700000000,
        'nonce': 'deadbeef',
        'email': 'ada@example.com',
        'email_verified': 'true',
    }

    def apple_token(**changes):
        claims = dict(apple)
        for key, value in changes.items():
            if value is None:
                claims.pop(key, None)
            else:
                claims[key] = value
        return sign(apple_header, claims, ec, True)

    tokens = {
        'appleToken': (
            apple_token(),
            "An Apple identity token: `sub` `000123.abc`, `aud` `com.club.app`,\n"
            "/// nonce `deadbeef`, e-mail `ada@example.com`, `iat` in 2023 and `exp` in 2033.",
        ),
        'appleTokenOtherSubject': (
            apple_token(sub='000999.zzz'),
            'The same key over other claims: `sub` `000999.zzz`.',
        ),
        'appleTokenHashedNonce': (
            apple_token(nonce=hashed_nonce),
            'Its nonce is the SHA-256 of `a-raw-nonce`, as Apple\'s flow sends it.',
        ),
        'appleTokenWithoutNonce': (
            apple_token(nonce=None),
            'No nonce claim at all.',
        ),
        'appleTokenFromElsewhere': (
            apple_token(iss='https://appleid.apple.com.evil.example'),
            'Issued by a look-alike issuer.',
        ),
        'appleTokenForAnotherApp': (
            apple_token(aud='com.other.app'),
            "Issued for another app's client id.",
        ),
        'appleTokenForSeveralApps': (
            apple_token(aud=['com.other.app', 'com.club.app']),
            "`aud` as a list, one of which is this app — what Google does when\n"
            "/// an app has several client ids.",
        ),
        'appleTokenWithoutSubject': (
            apple_token(sub=''),
            'Names no subject.',
        ),
        'appleTokenExpired': (
            apple_token(exp=1600000000, iat=1599999000),
            'Expired in 2020.',
        ),
        'appleTokenFromTheFuture': (
            apple_token(iat=2100000000, exp=2100003600),
            'Issued in 2036, by a clock far ahead of ours.',
        ),
        'appleTokenUnsigned': (
            '.'.join(apple_token().split('.')[:2]) + '.',
            "The claims of [appleToken] with `alg: none` and no signature —\n"
            "/// the oldest forgery there is.",
        ),
        'googleToken': (
            sign(
                {'alg': 'RS256', 'kid': 'rsa-1', 'typ': 'JWT'},
                {
                    'iss': 'https://accounts.google.com',
                    'sub': '11223344',
                    'aud': '1-android.apps.googleusercontent.com',
                    'exp': 2000000000,
                    'iat': 1700000000,
                    'email': 'ada@example.com',
                    'email_verified': True,
                    'name': 'Ada Lovelace',
                    'given_name': 'Ada',
                    'family_name': 'Lovelace',
                    'picture': 'https://example.com/a.png',
                },
                rsa,
                False,
            ),
            "A Google ID token: `sub` `11223344`, `aud`\n"
            "/// `1-android.apps.googleusercontent.com`, signed RS256.",
        ),
    }

    # `alg: none` needs its header rewritten, keeping nothing signed.
    unsigned_header = b64u(
        json.dumps({'alg': 'none', 'kid': 'ec-1', 'typ': 'JWT'}, separators=(',', ':')).encode()
    )
    parts = tokens['appleTokenUnsigned'][0].split('.')
    tokens['appleTokenUnsigned'] = (
        f'{unsigned_header}.{parts[1]}.',
        tokens['appleTokenUnsigned'][1],
    )

    print('// ' + __doc__.strip().splitlines()[0])
    print('// Remade by `tool/make_provider_tokens.py`; see its docstring. Every')
    print('// token below was signed by a key made for that run, and the private')
    print('// halves are gone.')
    print('library;')
    print()
    print("/// Apple's key set, one P-256 key.")
    print('const Map<String, Object?> appleJwks = {')
    print("  'keys': [")
    print('    ' + dart_map(ec_jwk, 4) + ',')
    print('  ],')
    print('};')
    print()
    print("/// Google's key set, one RSA key.")
    print('const Map<String, Object?> googleJwks = {')
    print("  'keys': [")
    print('    ' + dart_map(rsa_jwk, 4) + ',')
    print('  ],')
    print('};')
    print()
    print("/// The key a project signs Apple's client secret with — the `.p8`")
    print('/// file, as downloaded. Its private half is kept on purpose: the tests')
    print('/// sign with it and check what they signed.')
    print('const String appleSecretKeyPem =')
    print("    '''")
    print(secret_pem)
    print("''';")
    print()
    print('/// The public half of [appleSecretKeyPem], as a key set.')
    print('const Map<String, Object?> appleSecretKeyJwks = {')
    print("  'keys': [")
    print('    ' + dart_map(secret_jwk, 4) + ',')
    print('  ],')
    print('};')
    for name, (token, description) in tokens.items():
        print()
        print(f'/// {description}')
        print(f'const String {name} =')
        print(f"    '{token}';")


main()
