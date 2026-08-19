/// An opaque storage namespace resolved by a repository local store.
///
/// The application owns the meaning of this value: it may derive it from an
/// authenticated account, tenant, or another app-specific boundary. Core never
/// derives an application user identity itself.
class DwRepoScope {
  DwRepoScope(this.storageKey) {
    if (storageKey.trim().isEmpty) {
      throw StateError('Repository scope must not be blank.');
    }
    if (storageKey != storageKey.trim()) {
      throw StateError(
        'Repository scope must not contain surrounding whitespace.',
      );
    }
  }

  final String storageKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DwRepoScope && other.storageKey == storageKey;

  @override
  int get hashCode => storageKey.hashCode;

  @override
  String toString() => 'DwRepoScope($storageKey)';
}

/// An opaque, in-memory capability for one authenticated repository binding.
///
/// A store must issue a fresh instance for every scope transition, even when
/// the persistent [scope.storageKey] is the same (logout/login ABA). It is
/// deliberately not persisted, so a runtime binding can change without making
/// valid stored rows unreadable for a later binding under the same scope.
class DwRepoBinding {
  DwRepoBinding({required this.scope});

  final DwRepoScope scope;
  var _isActive = true;

  /// Whether this runtime capability has not been revoked.
  bool get isActive => _isActive;

  /// Revokes this capability when its authenticated binding changes.
  void invalidate() {
    _isActive = false;
  }
}
