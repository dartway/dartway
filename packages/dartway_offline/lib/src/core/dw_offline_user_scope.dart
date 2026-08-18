/// A stable authenticated identity that owns protected offline data.
///
/// Use an immutable account/profile identifier. A display name or email address
/// is not a valid value because either can change without the account changing.
class DwOfflineUserScope {
  DwOfflineUserScope({required String userScopeId})
    : userScopeId = _validatedUserScopeId(userScopeId);

  /// The trimmed stable identity used as the boundary for offline data.
  final String userScopeId;

  static String _validatedUserScopeId(String userScopeId) {
    final trimmedUserScopeId = userScopeId.trim();
    if (trimmedUserScopeId.isEmpty) {
      throw ArgumentError.value(
        userScopeId,
        'userScopeId',
        'must be a non-empty stable user identity.',
      );
    }
    return trimmedUserScopeId;
  }

  @override
  bool operator ==(Object other) {
    return other is DwOfflineUserScope && other.userScopeId == userScopeId;
  }

  @override
  int get hashCode => userScopeId.hashCode;

  @override
  String toString() => 'DwOfflineUserScope(userScopeId: $userScopeId)';
}
