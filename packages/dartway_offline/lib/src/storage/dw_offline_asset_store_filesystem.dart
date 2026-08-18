part of 'dw_offline_asset_store.dart';

extension _DwOfflineAssetStoreFilesystem on DwOfflineAssetStore {
  Future<bool> _fileMatches(
    File blobFile,
    DwOfflineAssetDescriptor descriptor,
  ) async {
    if (await blobFile.length() != descriptor.expectedSizeBytes) return false;
    final digest = await crypto.sha256.bind(blobFile.openRead()).first;
    return digest.toString() == descriptor.sha256Hex;
  }

  Future<void> _prepareScopeDirectories(String userScopeId) async {
    final scopeRoot = _scopeRoot(userScopeId);
    await _requireNoStoreLinkAncestors(scopeRoot);
    await scopeRoot.create(recursive: true);
    await _requireRegularDirectory(scopeRoot.path);
    for (final childDirectory in [
      scopeStagingDirectory(userScopeId),
      Directory(path.join(scopeRoot.path, 'blobs')),
    ]) {
      await _requireNoLink(childDirectory.path);
      await childDirectory.create();
      await _requireRegularDirectory(childDirectory.path);
    }
  }

  Future<void> _requireNoStoreLinkAncestors(Directory scopeRoot) async {
    final storeRoot = path.join(
      _applicationSupportDirectory.path,
      'dartway_offline',
    );
    final ancestorPaths = <String>[
      storeRoot,
      path.join(storeRoot, 'v1'),
      path.join(storeRoot, 'v1', 'scopes'),
      scopeRoot.path,
    ];
    for (final ancestorPath in ancestorPaths) {
      await _requireNoLink(ancestorPath);
    }
  }

  Directory _scopeRoot(String userScopeId) {
    if (userScopeId.isEmpty || userScopeId.trim() != userScopeId) {
      throw ArgumentError.value(userScopeId, 'userScopeId');
    }
    final scopeHash = crypto.sha256
        .convert(utf8.encode(userScopeId))
        .toString();
    return Directory(
      path.join(
        _applicationSupportDirectory.path,
        'dartway_offline',
        'v1',
        'scopes',
        scopeHash,
      ),
    );
  }

  String _blobName(String assetId, String assetRevision) {
    final identityBytes = <int>[
      ..._lengthPrefix(utf8.encode(assetId)),
      ..._lengthPrefix(utf8.encode(assetRevision)),
    ];
    return '${crypto.sha256.convert(identityBytes)}.blob';
  }

  List<int> _lengthPrefix(List<int> bytes) => [
    (bytes.length >> 24) & 0xff,
    (bytes.length >> 16) & 0xff,
    (bytes.length >> 8) & 0xff,
    bytes.length & 0xff,
    ...bytes,
  ];

  Future<void> _requireRegularFile(String entityPath) async {
    if (!await _isRegularFile(entityPath)) {
      throw const DwOfflineAssetIntegrityException(
        'Blob path is not a regular file.',
      );
    }
  }

  Future<bool> _isRegularFile(String entityPath) async =>
      await FileSystemEntity.type(entityPath, followLinks: false) ==
      FileSystemEntityType.file;

  Future<void> _requireRegularDirectory(String entityPath) async {
    if (await FileSystemEntity.type(entityPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const DwOfflineAssetIntegrityException(
        'Store path is not a regular directory.',
      );
    }
  }

  Future<void> _requireNoLink(String entityPath) async {
    if (await FileSystemEntity.type(entityPath, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const DwOfflineAssetIntegrityException(
        'Symbolic links are not accepted inside the asset store.',
      );
    }
  }

  Future<bool> _entityExists(String entityPath) async =>
      await FileSystemEntity.type(entityPath, followLinks: false) !=
      FileSystemEntityType.notFound;

  Future<void> _deleteInvalidBlob(String entityPath) async {
    final entityType = await FileSystemEntity.type(
      entityPath,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.file) {
      await File(entityPath).delete();
    } else if (entityType == FileSystemEntityType.link) {
      await Link(entityPath).delete();
    }
  }
}

final class _AssetDigestReceiver implements Sink<crypto.Digest> {
  crypto.Digest? _receivedDigest;

  crypto.Digest get digest => _receivedDigest!;

  @override
  void add(crypto.Digest digest) => _receivedDigest = digest;

  @override
  void close() {}
}
