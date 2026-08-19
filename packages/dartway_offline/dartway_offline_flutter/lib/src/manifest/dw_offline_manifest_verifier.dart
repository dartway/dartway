part of '../access/dw_offline_lease_policy.dart';

enum DwOfflineManifestVerificationStatus {
  verified,
  invalidEnvelope,
  unknownKey,
  invalidSignature,
  nonCanonicalPayload,
  invalidPayload,
  bindingMismatch,
  replayRejected,
  corrupt,
}

final class DwOfflineManifestVerificationResult {
  const DwOfflineManifestVerificationResult._({
    required this.status,
    this.verifiedManifest,
  });

  final DwOfflineManifestVerificationStatus status;
  final DwVerifiedOfflineManifest? verifiedManifest;
}

/// Strict v2 signed-manifest verification against an injected pinned keyring.
final class DwOfflineManifestVerifier {
  DwOfflineManifestVerifier({required Map<String, List<int>> pinnedPublicKeys})
    : _pinnedPublicKeys = Map<String, List<int>>.unmodifiable(
        pinnedPublicKeys.map(
          (keyId, publicKey) =>
              MapEntry(keyId, List<int>.unmodifiable(publicKey)),
        ),
      );

  static const int schemaVersion = DwOfflineManifestEnvelope.schemaVersion;
  static const String algorithmName = DwOfflineManifestEnvelope.algorithmName;
  static const Set<String> _envelopeFields =
      DwOfflineManifestEnvelope.envelopeFields;
  static const Set<String> _payloadFields = {
    'assets',
    'audience',
    'contentIdentity',
    'leaseId',
    'leaseIsRevoked',
    'leaseRecordVersion',
    'leaseValidUntilUtcEpochUs',
    'manifestRevision',
    'packageId',
    'repositoryContentDigest',
    'userScopeId',
    'verifiedServerUtcEpochUs',
  };
  static const Set<String> _assetFields = {
    'allowedRedirectHosts',
    'assetId',
    'assetRevision',
    'downloadUrl',
    'expectedSizeBytes',
    'isRequired',
    'logicalRelativePath',
    'mimeType',
    'sha256Hex',
  };

  final Map<String, List<int>> _pinnedPublicKeys;

  Future<DwOfflineManifestVerificationResult> verify({
    required String envelopeJson,
    required String expectedAudience,
    required String expectedUserScopeId,
    required String expectedPackageId,
    DwOfflineLeaseRecord previousLeaseRecord =
        const DwOfflineLeaseRecord.missing(),
  }) async {
    final envelope = _DwOfflineManifestSyntax.decodeObject(envelopeJson);
    if (envelope == null ||
        !_DwOfflineManifestSyntax.hasSingleFieldOccurrences(
          envelopeJson,
          _envelopeFields,
        ) ||
        !_DwOfflineManifestSyntax.hasExactFields(envelope, _envelopeFields) ||
        envelope['schemaVersion'] != schemaVersion ||
        envelope['algorithm'] != algorithmName ||
        envelope['keyId'] is! String ||
        envelope['payload'] is! String ||
        envelope['signature'] is! String) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.invalidEnvelope,
      );
    }
    final keyId = envelope['keyId']! as String;
    final publicKeyBytes = _pinnedPublicKeys[keyId];
    if (publicKeyBytes == null) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.unknownKey,
      );
    }
    if (publicKeyBytes.length != 32) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.invalidEnvelope,
      );
    }
    final payloadBytes = _DwOfflineManifestSyntax.decodeUnpaddedBase64Url(
      envelope['payload']! as String,
    );
    final signatureBytes = _DwOfflineManifestSyntax.decodeUnpaddedBase64Url(
      envelope['signature']! as String,
    );
    if (payloadBytes == null ||
        signatureBytes == null ||
        signatureBytes.length != 64) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.invalidEnvelope,
      );
    }
    final isSignatureValid = await Ed25519().verify(
      DwOfflineManifestEnvelope.signingBytes(
        schemaVersion: schemaVersion,
        algorithm: algorithmName,
        keyId: keyId,
        payloadBytes: payloadBytes,
      ),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!isSignatureValid) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.invalidSignature,
      );
    }
    final payloadJson = _DwOfflineManifestSyntax.decodeUtf8(payloadBytes);
    final payload = payloadJson == null
        ? null
        : _DwOfflineManifestSyntax.decodeObject(payloadJson);
    if (payload == null ||
        !_DwOfflineManifestSyntax.isRestrictedCanonicalJson(
          payloadBytes,
          payload,
        )) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.nonCanonicalPayload,
      );
    }
    final decodedManifest = _decodeManifest(payload);
    if (decodedManifest == null) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.invalidPayload,
      );
    }
    if (decodedManifest.manifest.audience != expectedAudience ||
        decodedManifest.manifest.userScopeId != expectedUserScopeId ||
        decodedManifest.manifest.packageId != expectedPackageId) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.bindingMismatch,
      );
    }
    final payloadDigest = crypto.sha256.convert(payloadBytes).toString();
    final verifiedLeaseInput = DwVerifiedOfflineLeaseInput._(
      userScopeId: decodedManifest.manifest.userScopeId,
      leaseId: decodedManifest.leaseId,
      recordVersion: decodedManifest.leaseRecordVersion,
      payloadDigest: payloadDigest,
      verifiedServerUtc: decodedManifest.verifiedServerUtc,
      validUntilUtc: decodedManifest.leaseValidUntilUtc,
      isRevoked: decodedManifest.leaseIsRevoked,
    );
    final acceptance = DwOfflineLeaseAcceptance.acceptVerified(
      verifiedInput: verifiedLeaseInput,
      previousRecord: previousLeaseRecord,
    );
    if (acceptance.status == DwOfflineLeaseAcceptanceStatus.replayRejected) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.replayRejected,
      );
    }
    if (acceptance.status == DwOfflineLeaseAcceptanceStatus.corrupt) {
      return const DwOfflineManifestVerificationResult._(
        status: DwOfflineManifestVerificationStatus.corrupt,
      );
    }
    return DwOfflineManifestVerificationResult._(
      status: DwOfflineManifestVerificationStatus.verified,
      verifiedManifest: DwVerifiedOfflineManifest._(
        manifest: decodedManifest.manifest,
        acceptedLeaseRecord: acceptance.record!,
        canonicalPayloadBytes: List<int>.unmodifiable(payloadBytes),
        canonicalEnvelopeJson: envelopeJson,
        verifiedLeaseInput: verifiedLeaseInput,
      ),
    );
  }

  _DecodedOfflineManifest? _decodeManifest(Map<String, Object?> payload) {
    if (!_DwOfflineManifestSyntax.hasExactFields(payload, _payloadFields)) {
      return null;
    }
    final audience = payload['audience'];
    final userScopeId = payload['userScopeId'];
    final packageId = payload['packageId'];
    final contentIdentity = payload['contentIdentity'];
    final manifestRevision = payload['manifestRevision'];
    final repositoryContentDigest = payload['repositoryContentDigest'];
    final leaseId = payload['leaseId'];
    final leaseRecordVersion = payload['leaseRecordVersion'];
    final verifiedServerUtcEpochUs = payload['verifiedServerUtcEpochUs'];
    final leaseValidUntilUtcEpochUs = payload['leaseValidUntilUtcEpochUs'];
    final leaseIsRevoked = payload['leaseIsRevoked'];
    final encodedAssets = payload['assets'];
    if (!_DwOfflineManifestSyntax.isNonEmptyExactText(audience) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(userScopeId) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(packageId) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(contentIdentity) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(manifestRevision) ||
        repositoryContentDigest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(repositoryContentDigest) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(leaseId) ||
        leaseRecordVersion is! int ||
        leaseRecordVersion <= 0 ||
        verifiedServerUtcEpochUs is! int ||
        leaseIsRevoked is! bool ||
        encodedAssets is! List<Object?>) {
      return null;
    }
    final verifiedServerUtc = _DwOfflineManifestSyntax.utcFromEpochMicroseconds(
      verifiedServerUtcEpochUs,
    );
    final leaseValidUntilUtc = _DwOfflineManifestSyntax.nullableUtcFromEpoch(
      leaseValidUntilUtcEpochUs,
    );
    if (verifiedServerUtc == null || leaseValidUntilUtc.isInvalid) {
      return null;
    }
    final assets = <DwOfflineAssetDescriptor>[];
    for (final encodedAsset in encodedAssets) {
      if (encodedAsset is! Map<String, Object?>) return null;
      final assetDescriptor = _decodeAsset(encodedAsset);
      if (assetDescriptor == null) return null;
      assets.add(assetDescriptor);
    }
    for (var index = 1; index < assets.length; index++) {
      if (_compareAssets(assets[index - 1], assets[index]) >= 0) return null;
    }
    return _DecodedOfflineManifest(
      manifest: DwOfflineManifest._(
        audience: audience! as String,
        userScopeId: userScopeId! as String,
        packageId: packageId! as String,
        contentIdentity: contentIdentity! as String,
        manifestRevision: manifestRevision! as String,
        repositoryContentDigest: repositoryContentDigest,
        assets: List<DwOfflineAssetDescriptor>.unmodifiable(assets),
      ),
      leaseId: leaseId! as String,
      leaseRecordVersion: leaseRecordVersion,
      verifiedServerUtc: verifiedServerUtc,
      leaseValidUntilUtc: leaseValidUntilUtc.value,
      leaseIsRevoked: leaseIsRevoked,
    );
  }

  DwOfflineAssetDescriptor? _decodeAsset(Map<String, Object?> encodedAsset) {
    if (!_DwOfflineManifestSyntax.hasExactFields(encodedAsset, _assetFields)) {
      return null;
    }
    final assetId = encodedAsset['assetId'];
    final assetRevision = encodedAsset['assetRevision'];
    final downloadUrl = encodedAsset['downloadUrl'];
    final redirectHosts = encodedAsset['allowedRedirectHosts'];
    final expectedSizeBytes = encodedAsset['expectedSizeBytes'];
    final sha256Hex = encodedAsset['sha256Hex'];
    final mimeType = encodedAsset['mimeType'];
    final logicalRelativePath = encodedAsset['logicalRelativePath'];
    final isRequired = encodedAsset['isRequired'];
    if (!_DwOfflineManifestSyntax.isNonEmptyExactText(assetId) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(assetRevision) ||
        downloadUrl is! String ||
        _DwOfflineManifestSyntax.validHttpsUrl(downloadUrl) == null ||
        redirectHosts is! List<Object?> ||
        expectedSizeBytes is! int ||
        expectedSizeBytes < 0 ||
        sha256Hex is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Hex) ||
        !_DwOfflineManifestSyntax.isNonEmptyExactText(mimeType) ||
        logicalRelativePath is! String ||
        !_DwOfflineManifestSyntax.isValidLogicalPath(logicalRelativePath) ||
        isRequired is! bool) {
      return null;
    }
    final validatedRedirectHosts = <String>[];
    for (final redirectHost in redirectHosts) {
      if (redirectHost is! String ||
          !_DwOfflineManifestSyntax.isValidDnsHost(redirectHost)) {
        return null;
      }
      validatedRedirectHosts.add(redirectHost);
    }
    for (var index = 1; index < validatedRedirectHosts.length; index++) {
      if (validatedRedirectHosts[index - 1].compareTo(
            validatedRedirectHosts[index],
          ) >=
          0) {
        return null;
      }
    }
    return DwOfflineAssetDescriptor._(
      assetId: assetId! as String,
      assetRevision: assetRevision! as String,
      downloadUrl: downloadUrl,
      allowedRedirectHosts: List<String>.unmodifiable(validatedRedirectHosts),
      expectedSizeBytes: expectedSizeBytes,
      sha256Hex: sha256Hex,
      mimeType: mimeType! as String,
      logicalRelativePath: logicalRelativePath,
      isRequired: isRequired,
    );
  }

  int _compareAssets(
    DwOfflineAssetDescriptor firstAsset,
    DwOfflineAssetDescriptor secondAsset,
  ) {
    final idComparison = firstAsset.assetId.compareTo(secondAsset.assetId);
    return idComparison == 0
        ? firstAsset.assetRevision.compareTo(secondAsset.assetRevision)
        : idComparison;
  }
}

final class _DecodedOfflineManifest {
  const _DecodedOfflineManifest({
    required this.manifest,
    required this.leaseId,
    required this.leaseRecordVersion,
    required this.verifiedServerUtc,
    required this.leaseValidUntilUtc,
    required this.leaseIsRevoked,
  });

  final DwOfflineManifest manifest;
  final String leaseId;
  final int leaseRecordVersion;
  final DateTime verifiedServerUtc;
  final DateTime? leaseValidUntilUtc;
  final bool leaseIsRevoked;
}

final class _NullableManifestInstant {
  const _NullableManifestInstant.valid(this.value) : isInvalid = false;
  const _NullableManifestInstant.invalid() : value = null, isInvalid = true;

  final DateTime? value;
  final bool isInvalid;
}

final class _DwOfflineManifestSyntax {
  const _DwOfflineManifestSyntax._();

  static Map<String, Object?>? decodeObject(String encodedJson) {
    try {
      final decodedValue = jsonDecode(encodedJson);
      return decodedValue is Map<String, Object?> ? decodedValue : null;
    } on FormatException {
      return null;
    }
  }

  static String? decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return null;
    }
  }

  static bool hasExactFields(
    Map<String, Object?> object,
    Set<String> expectedFields,
  ) =>
      object.length == expectedFields.length &&
      object.keys.toSet().containsAll(expectedFields);

  static bool hasSingleFieldOccurrences(
    String encodedJson,
    Set<String> expectedFields,
  ) {
    return expectedFields.every((fieldName) {
      final fieldPattern = RegExp('"${RegExp.escape(fieldName)}"\\s*:');
      return fieldPattern.allMatches(encodedJson).length == 1;
    });
  }

  static List<int>? decodeUnpaddedBase64Url(String encodedValue) {
    if (encodedValue.isEmpty ||
        encodedValue.contains('=') ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(encodedValue)) {
      return null;
    }
    try {
      return base64Url.decode(base64Url.normalize(encodedValue));
    } on FormatException {
      return null;
    }
  }

  static bool isRestrictedCanonicalJson(
    List<int> originalBytes,
    Map<String, Object?> payload,
  ) {
    if (!_hasRestrictedValues(payload)) return false;
    final renderedBytes = utf8.encode(jsonEncode(payload));
    if (originalBytes.length != renderedBytes.length) return false;
    for (var index = 0; index < originalBytes.length; index++) {
      if (originalBytes[index] != renderedBytes[index]) return false;
    }
    return true;
  }

  static bool _hasRestrictedValues(Object? jsonValue) {
    if (jsonValue == null || jsonValue is bool || jsonValue is int) return true;
    if (jsonValue is String) return !jsonValue.contains('\u0000');
    if (jsonValue is List<Object?>) {
      return jsonValue.every(_hasRestrictedValues);
    }
    if (jsonValue is Map<String, Object?>) {
      final keys = jsonValue.keys.toList(growable: false);
      for (var index = 1; index < keys.length; index++) {
        if (keys[index - 1].compareTo(keys[index]) >= 0) return false;
      }
      return jsonValue.values.every(_hasRestrictedValues);
    }
    return false;
  }

  static bool isNonEmptyExactText(Object? text) =>
      text is String && text.isNotEmpty && text.trim() == text;

  static Uri? validHttpsUrl(String encodedUrl) {
    if (!encodedUrl.startsWith('https://')) return null;
    final parsedUrl = Uri.tryParse(encodedUrl);
    final authorityEnd = encodedUrl.indexOf(RegExp(r'[/\?#]'), 8);
    final rawAuthority = authorityEnd < 0
        ? encodedUrl.substring(8)
        : encodedUrl.substring(8, authorityEnd);
    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        !parsedUrl.hasAuthority ||
        parsedUrl.userInfo.isNotEmpty ||
        parsedUrl.hasFragment ||
        parsedUrl.hasPort ||
        parsedUrl.host.isEmpty ||
        !isValidDnsHost(parsedUrl.host)) {
      return null;
    }
    if (rawAuthority != parsedUrl.host) return null;
    return parsedUrl;
  }

  static bool isValidDnsHost(String host) {
    if (host.isEmpty || host.endsWith('.') || host != host.toLowerCase()) {
      return false;
    }
    if (host.contains(':') || RegExp(r'^\d+(\.\d+){3}$').hasMatch(host)) {
      return false;
    }
    final labels = host.split('.');
    if (labels.length < 2 || host.length > 253) return false;
    for (final label in labels) {
      if (label.isEmpty ||
          label.length > 63 ||
          !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label)) {
        return false;
      }
    }
    return true;
  }

  static bool isValidLogicalPath(String logicalPath) {
    if (logicalPath.isEmpty ||
        logicalPath.startsWith('/') ||
        logicalPath.contains(r'\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(logicalPath) ||
        logicalPath.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      return false;
    }
    final segments = logicalPath.split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static DateTime? utcFromEpochMicroseconds(int epochMicroseconds) {
    if (epochMicroseconds < _minimumUtcEpochMicroseconds ||
        epochMicroseconds > _maximumUtcEpochMicroseconds) {
      return null;
    }
    return DateTime.fromMicrosecondsSinceEpoch(epochMicroseconds, isUtc: true);
  }

  static _NullableManifestInstant nullableUtcFromEpoch(Object? encodedEpoch) {
    if (encodedEpoch == null) {
      return const _NullableManifestInstant.valid(null);
    }
    if (encodedEpoch is! int) {
      return const _NullableManifestInstant.invalid();
    }
    final decodedInstant = utcFromEpochMicroseconds(encodedEpoch);
    return decodedInstant == null
        ? const _NullableManifestInstant.invalid()
        : _NullableManifestInstant.valid(decodedInstant);
  }
}
