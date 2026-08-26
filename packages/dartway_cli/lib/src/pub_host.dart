/// The pub host a `dart pub get` in this environment would actually talk to,
/// and a URL on it that answers cheaply.
///
/// Its own file because the obvious one-liner is wrong for the case that makes
/// the check worth having. A mirror may be served from a path
/// (`https://mirror.example/pub/`), and resolving a relative segment against
/// such a base drops its last segment — the probe would then report a host that
/// is reachable while the mirror behind it is not, which is worse than not
/// probing at all.
///
/// `PUB_HOSTED_URL` is the same variable pub itself reads, so whatever it names
/// is what the resolve step will hang on.
Uri pubHostProbeUri(String? pubHostedUrl) {
  final configured = pubHostedUrl?.trim() ?? '';
  var base = configured.isEmpty ? 'https://pub.dev' : configured;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  // Every pub host serves the package metadata API; asking about the CLI's own
  // package keeps the response small and needs no knowledge of the project.
  return Uri.parse('$base/api/packages/dartway_cli');
}
