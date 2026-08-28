/// The hosts an Nginx snippet sends traffic to, and which of them a Compose
/// stack has to declare.
///
/// A snippet under `deploy/nginx.d/` names Compose services as upstreams —
/// `proxy_pass http://minio:9000` — and nothing used to check that those
/// services are in the stack that was actually applied. Nginx resolves an
/// upstream once, at start, so the mismatch is not felt until something
/// restarts the proxy, which is the deploy's own last step. A staging stand
/// held a config naming a service it did not have for ten days, healthy the
/// whole time, and died at a deploy that had nothing to do with it.
///
/// One reading serves both sides of the guard: the local check reads the files
/// in the working copy, the deploy reads what is on the server. The rule must
/// be the same rule, or the two answers can differ for no reason anybody can
/// see.
class DwNginxUpstreams {
  const DwNginxUpstreams._();

  /// `proxy_pass http://host:8080;` and its siblings — the directives that
  /// name a backend by host.
  static final RegExp _pass = RegExp(
    r'\b(?:proxy_pass|grpc_pass|uwsgi_pass|fastcgi_pass)\s+'
    r'(?:[a-zA-Z0-9+.-]+://)?([^;\s/]+)',
  );

  /// `upstream name {` — an alias defined in the file itself, not a service.
  static final RegExp _upstreamBlock = RegExp(r'\bupstream\s+([^\s{]+)\s*\{');

  /// `server host:9000;` inside an upstream block.
  static final RegExp _server = RegExp(r'\bserver\s+([^;\s]+)');

  static final RegExp _comment = RegExp(r'#[^\n]*');

  /// Service names [conf] expects the stack to provide.
  ///
  /// Left out, because none of them is a Compose service and a check that
  /// reports them would be turned off within a week: anything holding a dot
  /// (an address or a fully qualified name), an nginx variable, a unix socket,
  /// `localhost`, and an alias the file defines through its own `upstream`
  /// block — for that one the servers inside the block are read instead.
  static Set<String> namesIn(String conf) {
    final text = conf.replaceAll(_comment, '');
    final aliases = _upstreamBlock
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet();

    final referenced = <String>{
      for (final m in _pass.allMatches(text)) m.group(1)!,
      for (final m in _server.allMatches(text)) m.group(1)!,
    };

    return {
      for (final raw in referenced)
        if (!aliases.contains(raw))
          if (_serviceName(raw) case final name?) name,
    };
  }

  /// Everything [snippets] reference and [services] does not declare, as
  /// `<file>: <host>` lines. Empty when they agree.
  static List<String> missing({
    required Map<String, String> snippets,
    required Set<String> services,
  }) {
    final out = <String>[];
    for (final entry in snippets.entries) {
      for (final name in namesIn(entry.value)) {
        if (!services.contains(name)) {
          out.add('${entry.key}: $name');
        }
      }
    }
    out.sort();
    return out;
  }

  /// Service names declared by a Compose document, read as text.
  ///
  /// Text rather than a YAML parse: on the server the answer comes from
  /// `docker compose config --services`, which is one name per line, and on
  /// this side the question is only ever asked about the rendered file plus
  /// the override.
  static Set<String> servicesInListing(String listing) => {
    for (final line in listing.split('\n'))
      if (line.trim().isNotEmpty && !line.startsWith(' ')) line.trim(),
  };

  static String? _serviceName(String raw) {
    final host = raw.split(':').first;
    if (host.isEmpty) return null;
    if (host.contains(r'$')) return null;
    if (host.contains('.')) return null;
    if (host.startsWith('unix')) return null;
    if (host == 'localhost') return null;
    return host;
  }
}
