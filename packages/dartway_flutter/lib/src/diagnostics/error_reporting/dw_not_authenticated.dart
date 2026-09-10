/// There is no session: the server was asked with a stored key and answered
/// that it does not know it.
///
/// Thrown where a failure would otherwise be, and it is not one. A key stops
/// being accepted whenever it expires, is revoked, the account is deleted, the
/// password changes or the app is pointed at another backend — all ordinary,
/// and all of them mean the same thing: *this person is not signed in*. That
/// is a state every app already knows how to render.
///
/// It used to arrive as `Exception('Authentication required (getOne for
/// UserProfile)')`, which a client can do nothing with but match on text. The
/// server has always had a name for the case — `DwApiResponse.notAuthenticated`
/// — and this type is that name surviving the trip: `isNotAuthenticated` on the
/// response, raised here by `DwRepository.processApiResponse`.
///
/// What acts on it:
///
/// - `DwSessionService` drops the stored key on startup and starts signed out,
///   instead of failing the launch and leaving the app with no first frame;
/// - an app's own `DwConfig.onErrorReport` can sort it out by type, the same
///   way it sorts out a `DwRefusal`, rather than alerting on a person whose
///   session simply ended.
///
/// [message] is the server's own account of where it happened — a diagnostic,
/// not a line for the screen. What the user should see is the sign-in screen.
class DwNotAuthenticated implements Exception {
  const DwNotAuthenticated(this.message);

  /// The server's description of the refused call, for logs and reports.
  final String message;

  @override
  String toString() => 'DwNotAuthenticated: $message';
}
