/// Resolves the address Studio's signed token must be issued for.
String dwStudioAccessOrigin({
  required bool releaseWeb,
  required String definedOrigin,
  required Uri baseUri,
}) {
  if (definedOrigin.trim().isNotEmpty) return definedOrigin;
  return releaseWeb ? baseUri.origin : '';
}
