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
      'x': 'uMmUKBZ9ENwtMMKMgOKEDkLWulo04ajfyGajY0PbH1A',
      'y': 'Y1a5s6btiCu9og9fwBbuTtxTYtPZuQAXtCrPgP__OIg',
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
      'n': '7hycr0ThNB6xKYMzJvoxQcFJX-j24FcVVh9lIBtnvEglWYJGrDP0tp-ylioH9opWejbebUseKQ64qyKTwcwIFjLxxbOHCd8skoFLS-nBC71vOI3lJYYS1UtMgCAtD3TU0Kfcs3oP6ADVOPJ0Qqx9-f6Xcg6ry2wzQhhs8zX0rIlidhfqpRotxhKY5kKIOxMuCpMjD8kdP95xFxox-j5Ad4QFBU540QEbWje4zbsWQ4Rm9SFklPwHemNXIP-7UwzlG2A1UKVmwKmWVi8Lu3eNnUVFdnhxhNo5J93MpYQ8AOFDrNIkUKhiYL449y8eixLb1aUmg6S8pdpsIa-gxzKNOQ',
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
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg0rwcVxKuRQIzNV4a
IBP2Sjbjh2ilGQmzG1A0R+9kAHmhRANCAASTCCO/tnWmPk47ZoD+vFIo2qUp1kd7
R7TYXRcadN5goPuAb+a1D/UBv2NatZ3g8sJYCOR3sulqkeYo2DNBSBm7
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
      'x': 'kwgjv7Z1pj5OO2aA_rxSKNqlKdZHe0e02F0XGnTeYKA',
      'y': '-4Bv5rUP9QG_Y1q1neDywlgI5Hey6WqR5ijYM0FIGbs',
    },
  ],
};

/// An Apple identity token: `sub` `000123.abc`, `aud` `com.club.app`,
/// nonce `deadbeef`, e-mail `ada@example.com`, `iat` in 2023 and `exp` in 2033.
const String appleToken =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.Cn-vCv-si_mZK0UQDeA_7VrXhvFIi75Orrp8kYNJ0XG77D77MMJc3MoK2uiU5Yf6wSiY1JPoheemcRxDrpt6fg';

/// The same key over other claims: `sub` `000999.zzz`.
const String appleTokenOtherSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwOTk5Lnp6eiIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.IuAxc2TwvE6SL7v-S17JH7oUhiiSYL8WdksSUJ1Wht-mCMrCGzMRwhfj1IXN4AxGbpNaJN75n-OBj0qHU-vPUQ';

/// Its nonce is the SHA-256 of `a-raw-nonce`, as Apple's flow sends it.
const String appleTokenHashedNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6IjJmZTI5MDAxMjM2ZjE1MzM4OTMxOTc4MmI0OGQzYTFmMTQxODU1MzgxNDg2MWI3ZWQzZGM0MTQ4MjBiYjRhNTAiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.EosJl-4QL6i1NhuQ53rDrZzxGAX9l-AWTOqA8wdjAB78aD62gXeToXpDMYEVJtmZ-eTu_cObsTCGpiN6TmLr2Q';

/// No nonce claim at all.
const String appleTokenWithoutNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.JPs0o8iP2XzU14udfdaMcR2NjaLbzPtvO34r6-XKkJPZWp1p9Myv1ZyOWvnlAMfHhTqWn_INAJTQ_d2E1nu37w';

/// Issued by a look-alike issuer.
const String appleTokenFromElsewhere =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tLmV2aWwuZXhhbXBsZSIsInN1YiI6IjAwMDEyMy5hYmMiLCJhdWQiOiJjb20uY2x1Yi5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.SOHM2YJmNlR9_hoxyC_nyogugTl9Sbp_jG3poFqBUtfkrb-5I20vkblObg8WsAT2GSo-A32PkODud3GnXQD1NA';

/// Issued for another app's client id.
const String appleTokenForAnotherApp =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5vdGhlci5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.eelaNiW6Y8FlEitjDiH0d8Ar7sS3PE-8oCXJlWwBL_oZztIbzsLMg-flCqQ3ltO_4yf4SCSO2jZetKMXjVVP6w';

/// `aud` as a list, one of which is this app — what Google does when
/// an app has several client ids.
const String appleTokenForSeveralApps =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6WyJjb20ub3RoZXIuYXBwIiwiY29tLmNsdWIuYXBwIl0sImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.7wPVlWKLbWS7h4mbgwIOMzpMWJYZ-_XPfb12rq891Xt-oz5spFHh48HH7Mojvhuk0qMKBC5Z3-FGKkas-sg9Jw';

/// Names no subject.
const String appleTokenWithoutSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiIiwiYXVkIjoiY29tLmNsdWIuYXBwIiwiZXhwIjoyMDAwMDAwMDAwLCJpYXQiOjE3MDAwMDAwMDAsIm5vbmNlIjoiZGVhZGJlZWYiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.kHaRAj6Y-_-r-gEcmlyA_vW3ga4zIXUKyc1tt0XXL7-VUK0jrswQoAUoeQdFrHGo-4TyDkDQ4z08weYj8T1fPA';

/// Expired in 2020.
const String appleTokenExpired =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MTYwMDAwMDAwMCwiaWF0IjoxNTk5OTk5MDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.ccbtYKOcgp_Li8gK64QYoCiFs17l1OGj5H0HF5Zp2zilSL0-v0WC9Qry1qRmwnI5vemTwKS_idujVq7Sesys7Q';

/// Issued in 2036, by a clock far ahead of ours.
const String appleTokenFromTheFuture =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjEwMDAwMzYwMCwiaWF0IjoyMTAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.efQ5_dVxMrBkp8HiswYpYvGyAAIrToKvBBiO3z9JkV1hU9Le30Qe6cHTk1OXsK9K2LwP7sad36b0hjw1EFS4lQ';

/// The claims of [appleToken] with `alg: none` and no signature —
/// the oldest forgery there is.
const String appleTokenUnsigned =
    'eyJhbGciOiJub25lIiwia2lkIjoiZWMtMSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.';

/// A Google ID token: `sub` `11223344`, `aud`
/// `1-android.apps.googleusercontent.com`, signed RS256.
const String googleToken =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiIxMTIyMzM0NCIsImF1ZCI6IjEtYW5kcm9pZC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiQWRhIExvdmVsYWNlIiwiZ2l2ZW5fbmFtZSI6IkFkYSIsImZhbWlseV9uYW1lIjoiTG92ZWxhY2UiLCJwaWN0dXJlIjoiaHR0cHM6Ly9leGFtcGxlLmNvbS9hLnBuZyJ9.PoEW_HHeHSIbOW4CVxod3HJrwou2G0E_SyZcpFNDd7vdc9yItS87lBM_qv0NFZoxkJ9rjqeKQ_ZsMGpsMfqt0mup0rV1PxAez5PGsBHdlgFTM9Oh55VnU36NSRiPhSdJvoJ1qy-NlaHx7bbychyGScUZmJmBjBC_6zKIyOLLvZq42fPMAz9PsKI3RNWpbX6bQSXCQSpK9KLF4p2ViwUXWofi-TN9QWASJ_6aEYNGkEUa9ytcK1bp7KLLs0JXHly-dwV09YzMcoublvg58iBpBDU6jRsoCDJf7Xrkil0NoN8y-NAbEPgZOmmsw9qQh9hqjdr1nUmr_ZbRA8qDAJSArg';

/// The same e-mail, `email_verified: false` — Google's claim, not the
/// app's: `linkByVerifiedEmail` must never link on this.
const String googleTokenEmailUnverified =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiIxMTIyMzM0NSIsImF1ZCI6IjEtYW5kcm9pZC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwibmFtZSI6IkFkYSBMb3ZlbGFjZSIsImdpdmVuX25hbWUiOiJBZGEiLCJmYW1pbHlfbmFtZSI6IkxvdmVsYWNlIiwicGljdHVyZSI6Imh0dHBzOi8vZXhhbXBsZS5jb20vYS5wbmcifQ.eCGeZ2A3WUzJEgE6YOkVZPr40ktRlm7GWI1FfOcRsua0YgNeDX05tjkB2yS-taBU_uolJfAdNQCjgwZNodz1ksg3WsPJMbnnz2PlADuBvUdwEkW_VJfPe_WiqO-csHkUAWTCYGjSWMXryD2-BD94JyWx6FdM5X2Uol6zMupPsqht072novl9kXByqtaufFTXUkst_pwcC26yYAXfoHKtEfSFvLBs-osNoJRAFQLjds2njXwuF0Wo2A0GROcZE3lQn74q086GxEhMuaRlcAZn35Bn5jltQ8vBkTbwCLAp2b5Wpd6c9V20BoeEBJuf4ylce5y7HwHZUioCtfw9Zuy60w';

/// The same e-mail, no `email_verified` claim at all — absent is not
/// verified either.
const String googleTokenNoEmailVerifiedClaim =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiIxMTIyMzM0NiIsImF1ZCI6IjEtYW5kcm9pZC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsIm5hbWUiOiJBZGEgTG92ZWxhY2UiLCJnaXZlbl9uYW1lIjoiQWRhIiwiZmFtaWx5X25hbWUiOiJMb3ZlbGFjZSIsInBpY3R1cmUiOiJodHRwczovL2V4YW1wbGUuY29tL2EucG5nIn0.pcedVZCCd_0qZJYtbchTwQ504Cm4DfPbEFZcx18jjAAksg0aFYB1jA8zrNEMHkfvxk5hhCT7gLgzLfq2CUfgsZcfF40MiW1HMOvCIXUyesOgo_GFKGuhuavAeWRiqyzsYj7F6jEPvO2ieGdqjlt_zeprTlD2ZyupLkwpC8h-1hF1rdcD1o6dwTPsGNrfcola5sAemuQXsallbKPt9QAMgVuGOWlEQG9jYVmBnMXKwyxYaI6J0Hr2UjYWlF9uZZ7wjHsnUyycvJ91f8fLmBwHWyrwMZ4diKCiUR0B6hVbLhgrXqjs1DUCpkJP9hMOp5As8azbC9PT1HuxIynLeSYl-Q';
