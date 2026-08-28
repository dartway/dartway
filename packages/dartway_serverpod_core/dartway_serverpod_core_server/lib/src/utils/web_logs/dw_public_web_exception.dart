/// A failure whose message the caller is allowed to read.
///
/// Everything a web route throws ends up in the HTTP response one way or
/// another; the only question is whether the text was written for that reader.
/// Without a type saying so, the honest answer is no — a database error
/// carries its query, a null check carries a file path, a Serverpod failure
/// carries whatever the framework felt like saying — and the caller of a
/// webhook is not somebody we authenticated.
///
/// So the split is a type rather than a convention: throw this one and the
/// [message] is the response; throw anything else and the caller is told that
/// something failed, while the detail goes where detail belongs — the alert
/// and the `DwWebServerLog` row.
///
/// ```dart
/// if (payload['orderId'] == null) {
///   throw const DwPublicWebException('orderId is required');
/// }
/// ```
class DwPublicWebException implements Exception {
  const DwPublicWebException(this.message, {this.statusCode = 400});

  /// Shown to the caller verbatim. Write it for them.
  final String message;

  /// Defaults to 400: a message worth showing the caller is almost always
  /// about what they sent.
  final int statusCode;

  @override
  String toString() => 'DwPublicWebException($statusCode): $message';
}
