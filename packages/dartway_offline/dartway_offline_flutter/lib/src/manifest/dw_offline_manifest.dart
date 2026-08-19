part of '../access/dw_offline_lease_policy.dart';

/// A verified generic package manifest.
final class DwOfflineManifest {
  const DwOfflineManifest._({
    required this.audience,
    required this.userScopeId,
    required this.packageId,
    required this.contentIdentity,
    required this.manifestRevision,
    required this.repositoryContentDigest,
    required this.assets,
  });

  final String audience;
  final String userScopeId;
  final String packageId;
  final String contentIdentity;
  final String manifestRevision;
  final String repositoryContentDigest;
  final List<DwOfflineAssetDescriptor> assets;
}

/// Capability returned only after signature, canonical form, and binding checks.
final class DwVerifiedOfflineManifest {
  const DwVerifiedOfflineManifest._({
    required this.manifest,
    required this.acceptedLeaseRecord,
    required this.canonicalPayloadBytes,
    required this.canonicalEnvelopeJson,
    required DwVerifiedOfflineLeaseInput verifiedLeaseInput,
  }) : _verifiedLeaseInput = verifiedLeaseInput;

  final DwOfflineManifest manifest;
  final DwOfflineLeaseRecord acceptedLeaseRecord;
  final List<int> canonicalPayloadBytes;
  final String canonicalEnvelopeJson;
  final DwVerifiedOfflineLeaseInput _verifiedLeaseInput;

  String get payloadDigest => acceptedLeaseRecord.lease!.payloadDigest;

  DwOfflineLeaseAcceptanceResult reverifyPersistedLease({
    required DwPersistedOfflineLease persistedClaims,
    DwOfflineLeaseRecord previousRecord = const DwOfflineLeaseRecord.missing(),
  }) {
    return DwOfflineLeaseAcceptance.reverifyPersisted(
      persistedClaims: persistedClaims,
      verifiedInput: _verifiedLeaseInput,
      previousRecord: previousRecord,
    );
  }

  DwTrustedTime createTrustedTime({
    required DwTrustedTimeSource timeSource,
    DwTrustedTimeSnapshot? previousSnapshot,
  }) {
    return DwTrustedTime.fromVerifiedInput(
      verifiedInput: DwVerifiedTimeInput._(leaseInput: _verifiedLeaseInput),
      timeSource: timeSource,
      previousSnapshot: previousSnapshot,
    );
  }
}
