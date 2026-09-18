// Makes the tokens `test/fixtures/provider_tokens.dart` holds.
// Remade by `tool/make_provider_tokens.py`; see its docstring. Every
// token below was signed by a key made for that run, and the private
// halves are gone.
library;

/// Apple's key set, one P-256 key.
const Map<String, Object?> appleJwks = {
  'keys': [
    {
      'kty': 'EC',
      'kid': 'ec-1',
      'use': 'sig',
      'alg': 'ES256',
      'crv': 'P-256',
      'x': 'WLVyYG6XDeR-QmeYXsJMRJRz7xKEqdev4h4uFkq2nwc',
      'y': 'hw1J0DeOWxuE3wsEm1CsHG0WF9LeLXgrNbnEdX6Kllg',
    },
  ],
};

/// Google's key set, one RSA key.
const Map<String, Object?> googleJwks = {
  'keys': [
    {
      'kty': 'RSA',
      'kid': 'rsa-1',
      'use': 'sig',
      'alg': 'RS256',
      'n': 'xWV0uKsLf6epWeNSrnwvab7ada_MwFZ0nh4eJw331SLOiFwRY8WhHF0zkt2E-TFBuphpZWo7zYJcI3U1jo2YD2Ekvg46hgWSkyIddXihb4hNUZyLGLgiyuAS-rMwh6xoMoZO02fnHB9l22Vf9-5HR1_VU3w8PqvsTjcgfZQ60GS2oKDvImU7swUWQ4_7vT7RXWdMZaBZaei_AYLom3mp4sXvezO81lbtjG1Z6N2o-RUsPE0xQICuCtwiXzN1ciDY2coqzD82FsZO4TScGBocxaxF8RWCmYuol3lqStwP3iPjCjCgnimhSuglf7s5nSeFY7jG3NPA1prpKrrUlF9Fnw',
      'e': 'AQAB',
    },
  ],
};

/// The key a project signs Apple's client secret with — the `.p8`
/// file, as downloaded. Its private half is kept on purpose: the tests
/// sign with it and check what they signed.
const String appleSecretKeyPem =
    '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgS3/qqCmKTupUj/Ot
lkTIjEcbCL09hQXlsoQs80j4sLOhRANCAARDFiUOUzx4zvHStI1szATywz0dzmfl
oS6sN2F4wfIwf4yZc24htVzgXmKMEHVuYgdCCam07EB6yhQne6aRFP8e
-----END PRIVATE KEY-----
''';

/// The public half of [appleSecretKeyPem], as a key set.
const Map<String, Object?> appleSecretKeyJwks = {
  'keys': [
    {
      'kty': 'EC',
      'kid': 'secret-1',
      'use': 'sig',
      'alg': 'ES256',
      'crv': 'P-256',
      'x': 'QxYlDlM8eM7x0rSNbMwE8sM9Hc5n5aEurDdheMHyMH8',
      'y': 'jJlzbiG1XOBeYowQdW5iB0IJqbTsQHrKFCd7ppEU_x4',
    },
  ],
};

/// An Apple identity token: `sub` `000123.abc`, `aud` `com.club.app`,
/// nonce `deadbeef`, e-mail `ada@example.com`, `iat` in 2023 and `exp` in 2033.
const String appleToken =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.qmKc2_su67Q56TbnVyEgfbEvcAERA2JCA-kQ4RUP3WaRCCTzsckkYXxG5p7w03phMq7-rGndYUPZnP07gZr2zA';

/// The same key over other claims: `sub` `000999.zzz`.
const String appleTokenOtherSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwOTk5Lnp6eiIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.kDh8AGlsKpo0N4v39X-2pL_mh9yxxvqYJFadFiMi6Oh5-Lx7cj345271CNh7Nw2DWGGSVOVEYmklqfe1smFRHw';

/// Its nonce is the SHA-256 of `a-raw-nonce`, as Apple's flow sends it.
const String appleTokenHashedNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6IjJmZTI5MDAxMjM2ZjE1MzM4OTMxOTc4MmI0OGQzYTFmMTQxODU1MzgxNDg2MWI3ZWQzZGM0MTQ4MjBiYjRhNTAiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.xwZdA0_1_l4CE0Noy1KbKVk3zdnHNbg0h17-gimfG_QBqPVNDZ-Mfpy5_pX8oHyH2CaeXz6TvS0_T8brHt4ToQ';

/// No nonce claim at all.
const String appleTokenWithoutNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.iN1aiRctmJ05b0aygzd9ycXukocv9sk-V5naTMtVWYPreJm3Jo5CKltqTojetsD_7BDCil22nrA8ElLXSKDPlg';

/// Issued by a look-alike issuer.
const String appleTokenFromElsewhere =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tLmV2aWwuZXhhbXBsZSIsInN1YiI6IjAwMDEyMy5hYmMiLCJhdWQiOiJjb20uY2x1Yi5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.fvM_dtYBoMtkQTeLMbbUdWfnYCdWIIv-63Sl9tS7XOnG7EUNWHqpoAUFgUGnzrF8luz2DVYeKATfP-5O_Fen0w';

/// Issued for another app's client id.
const String appleTokenForAnotherApp =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5vdGhlci5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.SPavJxmXQWVQAiMacT3MjNDy7hbt1RvkMbx6740o7Bn-AJKzBcfDSHqjAzMD4YcHgEABCxc2Zi6D-09t5FyPGw';

/// `aud` as a list, one of which is this app — what Google does when
/// an app has several client ids.
const String appleTokenForSeveralApps =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6WyJjb20ub3RoZXIuYXBwIiwiY29tLmNsdWIuYXBwIl0sImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.uBGMwWN7-vjpWCfzeNjri7E7ijyFfUvK8FNeMMWvD3sBXvGNAcsAqi86E9Gg-mNM8pPpFi2HGAnSR3VHTWUxGQ';

/// Names no subject.
const String appleTokenWithoutSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiIiwiYXVkIjoiY29tLmNsdWIuYXBwIiwiZXhwIjoyMDAwMDAwMDAwLCJpYXQiOjE3MDAwMDAwMDAsIm5vbmNlIjoiZGVhZGJlZWYiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.k3kBLZDhhcWmIEQlEP46nOA7_JuFsK3MqXPJUy73blJtUPHBsoimKlzf4X3EpjfMrmPk797qFIepQ4yZitPlIA';

/// Expired in 2020.
const String appleTokenExpired =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MTYwMDAwMDAwMCwiaWF0IjoxNTk5OTk5MDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.9IbDAbA9B0b73wU32dVQqb8gw9oad7dkHYsHl6xcrmjKs9FeQerbsXHNo98QjExKS7R_uL5x6twwzHy6qVPouA';

/// Issued in 2036, by a clock far ahead of ours.
const String appleTokenFromTheFuture =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjEwMDAwMzYwMCwiaWF0IjoyMTAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.QxszjE2tZ6mtBZ2rsS2gWqZhuvH7qjK47FV_5hiVIymDycnay8-phTB2hqlRtMgv15NlukdpC4cdhAAtFydTjw';

/// The claims of [appleToken] with `alg: none` and no signature —
/// the oldest forgery there is.
const String appleTokenUnsigned =
    'eyJhbGciOiJub25lIiwia2lkIjoiZWMtMSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.';

/// A Google ID token: `sub` `11223344`, `aud`
/// `1-android.apps.googleusercontent.com`, signed RS256.
const String googleToken =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiIxMTIyMzM0NCIsImF1ZCI6IjEtYW5kcm9pZC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiQWRhIExvdmVsYWNlIiwiZ2l2ZW5fbmFtZSI6IkFkYSIsImZhbWlseV9uYW1lIjoiTG92ZWxhY2UiLCJwaWN0dXJlIjoiaHR0cHM6Ly9leGFtcGxlLmNvbS9hLnBuZyJ9.GNWcROBO4VaH8__oKgK0AZHrNX7Wfb-XyWCG0qktUvdqXtCs-RNiwKhYq51ai21W6Ibjk87BnOd9pWEtToYfUOLkHEb1kzqZPh-z0jHCWSTf7Z3UM5cqmf-mlAbsw5u2SuOcY45w2m-OozWu5wf88zCN0OrAXITvfBQoM3fORv7xPYixaCQp4KLx_VuN7Mc6jOxYKGrA1TE9DYfrMm1-bGxVxZe8JQG0RIv3VV_2NUUh6D5Sn6vtZ0gAt3ao-RejYBNrB4WEPX2o406PsI1ExDTNCZsspgj6mDksBylx73rTLqdEFElC6T8gBREM-C-UmWfmFCBpPVQfMXrDYYNx2g';
