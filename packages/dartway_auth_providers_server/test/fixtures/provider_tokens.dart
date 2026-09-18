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
      'x': '-yknBT7tJSnxBgYtabf1eTY31rhpHQ42JfJyHlbuxZg',
      'y': 'USpKsx8cD2z4tylfDk9uPsokOmAkMqqxdnFXvvacXac',
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
      'n': 'o2PJvBvzy2X3VrnZ86nwrk4jsMYmmDljQLoliZsxRbH2Oq3p20J6lzx1JCco5ETAJqmzFoNH1lGXt8N-dCginAwUyUdJEKVnGCN7x4JjcxxQdXAEzylUz5zlYFTieW6qpAaYsn8RGxrmXd-CMofXqneA_N67jgYzhVUjdwMx-m6zfURKAFMZwW4Ce_jkpt3cK9CfjZHrHBqXas_z72ypWUJNBnGtuyS3MLYMWOI2h-HQDX2aS3VXcg702Op7VuqXrGgZihgtGX3tgPAfSQe9H_l3RrvzG5r3Ejy2m9ibmsL_0w_Wf2_e41KjWK5zHWFhbFK27d-l8okEVPildvKdYQ',
      'e': 'AQAB',
    },
  ],
};

/// An Apple identity token: `sub` `000123.abc`, `aud` `com.club.app`,
/// nonce `deadbeef`, e-mail `ada@example.com`, `iat` in 2023 and `exp` in 2033.
const String appleToken =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.MmVaWfb2O3LNysFNtEOZZW2wrv5FwIH9Y2FqOfsaWW3MJu6ErHUUjTXf8cn_zFVMrVIE2X5-nrRagIGTzF_XCQ';

/// The same key over other claims: `sub` `000999.zzz`.
const String appleTokenOtherSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwOTk5Lnp6eiIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.mS3bUx2cvGhkZO0agCErTcF4CVvniGQhNJVF4LeqPkM-FZm0ENsYeABv3bV2Sn8DJ8XcBQ-GFDx7xzXgrja-Iw';

/// Its nonce is the SHA-256 of `a-raw-nonce`, as Apple's flow sends it.
const String appleTokenHashedNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6IjJmZTI5MDAxMjM2ZjE1MzM4OTMxOTc4MmI0OGQzYTFmMTQxODU1MzgxNDg2MWI3ZWQzZGM0MTQ4MjBiYjRhNTAiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.pzmpInphIE1Oke9hMbm3i9i_VIfCjV89hiPAm2jxfsMIE1l2BRa3cnWn-4fcViCax5-quEfXXM7T8XkSutViMg';

/// No nonce claim at all.
const String appleTokenWithoutNonce =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.iIEnZ2aZwFZLRTMtBCOdIsjoJBlmNoocCvmE4ay_MpH70KSMzu494Q3HohlTJ_o3wOUVH5IeUiXD7IiZYh_l3w';

/// Issued by a look-alike issuer.
const String appleTokenFromElsewhere =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tLmV2aWwuZXhhbXBsZSIsInN1YiI6IjAwMDEyMy5hYmMiLCJhdWQiOiJjb20uY2x1Yi5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.mD-RoxzPOZ5aIO_ItAPH2tl4DpuK3aRyu9Bsd3RmfMecIqSVP9ExvhJd5Z4a4Y0R-bYaUmQnZjv9WCu-najtag';

/// Issued for another app's client id.
const String appleTokenForAnotherApp =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5vdGhlci5hcHAiLCJleHAiOjIwMDAwMDAwMDAsImlhdCI6MTcwMDAwMDAwMCwibm9uY2UiOiJkZWFkYmVlZiIsImVtYWlsIjoiYWRhQGV4YW1wbGUuY29tIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIn0.EzEVO5KFo4Ugh6G76AC4harNSTJEvKbj2dYBnJ5xR6bHetudY27y2myN2fsHixifYScYsQRN6R-iQJjrZt7EVw';

/// `aud` as a list, one of which is this app — what Google does when
/// an app has several client ids.
const String appleTokenForSeveralApps =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6WyJjb20ub3RoZXIuYXBwIiwiY29tLmNsdWIuYXBwIl0sImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.79qKil_kdmLXNg3531etFPgRpiNTCmXDQYoBZiHayxLISRSanL1vrGWnxYR8V-9ne6FVuYYN_aQbz-NB0C7caA';

/// Names no subject.
const String appleTokenWithoutSubject =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiIiwiYXVkIjoiY29tLmNsdWIuYXBwIiwiZXhwIjoyMDAwMDAwMDAwLCJpYXQiOjE3MDAwMDAwMDAsIm5vbmNlIjoiZGVhZGJlZWYiLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSJ9.ACipgJ6gpeB2NUlanklu5-CvpfbgEH3OFdovcWadFimOr9rupPALxuT9faj-Pd9HRKcP59Z9rPbJBjOgzFQydQ';

/// Expired in 2020.
const String appleTokenExpired =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MTYwMDAwMDAwMCwiaWF0IjoxNTk5OTk5MDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.zcLztD9IVg-GqP1_diPbzcFNl8iyeDF5C8Px9SBug5TP16mGt7X7V8n9VLE7wJoHegS-d-m-_Au5YWaGPPQpTQ';

/// Issued in 2036, by a clock far ahead of ours.
const String appleTokenFromTheFuture =
    'eyJhbGciOiJFUzI1NiIsImtpZCI6ImVjLTEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjEwMDAwMzYwMCwiaWF0IjoyMTAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.SMs2FnIb1bEAt6IXK8VrnhL9ZuBdU0jo_U5KwANfrlTUlUS-e_c9FmCo35mu4Lbusgw5QDl4UtY6QKkDz7zdsw';

/// The claims of [appleToken] with `alg: none` and no signature —
/// the oldest forgery there is.
const String appleTokenUnsigned =
    'eyJhbGciOiJub25lIiwia2lkIjoiZWMtMSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwic3ViIjoiMDAwMTIzLmFiYyIsImF1ZCI6ImNvbS5jbHViLmFwcCIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJub25jZSI6ImRlYWRiZWVmIiwiZW1haWwiOiJhZGFAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUifQ.';

/// A Google ID token: `sub` `11223344`, `aud`
/// `1-android.apps.googleusercontent.com`, signed RS256.
const String googleToken =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiIxMTIyMzM0NCIsImF1ZCI6IjEtYW5kcm9pZC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImV4cCI6MjAwMDAwMDAwMCwiaWF0IjoxNzAwMDAwMDAwLCJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiQWRhIExvdmVsYWNlIiwiZ2l2ZW5fbmFtZSI6IkFkYSIsImZhbWlseV9uYW1lIjoiTG92ZWxhY2UiLCJwaWN0dXJlIjoiaHR0cHM6Ly9leGFtcGxlLmNvbS9hLnBuZyJ9.gxL6YptFDa2XG9fKMfMGEWu_T9YAi1MTIFB-MklCbjJFBhZWToi9RVGo9KzvLWVrHpMaB_Hy_OCpb5Z_fhxvYmZjsMRx2-w3REiFvmmWDO6cXbRa-NXGKjzGH0333K8ROj9kU1aRDJ28CfdmA2rqnXV5yt4NLJNOBYPk-69aR43oHnD9kpLiou8kK2XDZqoChE8u-4n92Bxcdtd7IXwP2DfaxvlkNPCo4fzg0dBq7510vl2yAu9zJ1Q67hRoIVJTkA2ixPxYQefBPaRRM8YKre-xXEOhnNORArz0oEM2fjqUuh0iPCHIroZ3cPDRn6vJAIy_Wan60t_XOQmo9kkp8Q';
