# dartway_offline_server

The server half of DartWay offline: signing the manifests a device is allowed to trust.

A manifest says which assets belong to an offline package, what they hash to, where to fetch them,
and how long the holder may keep them. The device believes none of it unless it is signed by a key
it has pinned, so producing that signature correctly is this package's whole job.

Plain Dart — no Serverpod dependency, no endpoints, no tables. Where the manifest is served from,
where leases are stored and how they are revoked belong to the application; this package makes the
bytes it signs canonical and the signature verifiable.

```dart
final signer = await DwOfflineManifestSigner.fromSeed(
  keyId: 'key-v1',
  privateKeySeed: seedFromSecretStorage,
);

final envelope = await signer.sign(
  DwOfflineManifestClaims(
    audience: 'my-app-mobile',
    userScopeId: '$userId',
    packageId: 'course:101',
    // ...
    assets: assets,
  ),
);
```

The signing frame — domain separator, schema version, algorithm, length-prefix framing — lives in
`dartway_offline_shared` and is read by both halves. It is not restated here, because a frame that
drifts between signer and verifier does not fail to compile; it fails as an unverifiable manifest
on a stranger's device.

Claims are validated before they are signed: an asset URL must be https without credentials or a
fragment, a logical path must not escape its root, hashes must be sha-256 hex, and asset identities
must be unique. Signing something malformed is not offered.
