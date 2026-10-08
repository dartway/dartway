import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Explicit server coordinates; no inherited DW_DATABASE_* / DW_STORAGE_*.
class TestServerUrl {
  TestServerUrl._(this.uri, this.user, this.password);

  final Uri uri;
  final String user;
  final String password;

  static TestServerUrl parse(String value, {required bool database}) {
    // Never include the input in diagnostics: it carries credentials.
    try {
      final uri = Uri.parse(value);
      final colon = uri.userInfo.indexOf(':');
      final user = Uri.decodeComponent(
        colon < 0 ? uri.userInfo : uri.userInfo.substring(0, colon),
      );
      final password = colon < 0
          ? ''
          : Uri.decodeComponent(uri.userInfo.substring(colon + 1));
      if (!(database
              ? uri.scheme == 'postgres'
              : ['http', 'https'].contains(uri.scheme)) ||
          uri.host.isEmpty ||
          user.isEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
          (database
              ? uri.pathSegments.length != 1 ||
                    uri.pathSegments.single.isEmpty ||
                    password.isEmpty
              : (uri.path != '' && uri.path != '/') || password.isEmpty)) {
        throw const FormatException();
      }
      return TestServerUrl._(uri.replace(userInfo: ''), user, password);
    } on FormatException {
      throw FormatException(
        database
            ? '--database-url must be postgres://user:password@host[:port]/maintenance-db'
            : '--storage-url must be http[s]://access-key:secret-key@host[:port]',
      );
    }
  }

  /// Resolve before connecting. A hostname whose
  /// answers mix loopback and remote addresses is not a local test server.
  Future<Map<String, String>> environment({
    required bool database,
    required bool allowRemote,
  }) async {
    final addresses = await InternetAddress.lookup(uri.host);
    if (addresses.isEmpty ||
        (!allowRemote && addresses.any((address) => !address.isLoopback))) {
      throw const FormatException(
        'Test servers must resolve only to loopback. '
        'Use --allow-remote-test-server only for a dedicated test server.',
      );
    }
    final host = uri.host;
    if (database) {
      return {
        'DW_DATABASE_HOST': host,
        'DW_DATABASE_PORT': '${uri.hasPort ? uri.port : 5432}',
        'DW_DATABASE_NAME': uri.pathSegments.single,
        'DW_DATABASE_USER': user,
        'DW_DATABASE_PASSWORD': password,
        'DW_DATABASE_SSL': 'false',
      };
    }
    return {
      'DW_STORAGE_ENDPOINT': '${uri.replace(host: host, path: '')}',
      'DW_STORAGE_ACCESS_KEY': user,
      'DW_STORAGE_SECRET_KEY': password,
      'DW_STORAGE_PATH_STYLE': 'true',
      'DW_STORAGE_REGION': 'us-east-1',
    };
  }
}

/// The cleanup worker runs with the project's resolved framework. No dependency
/// resolution, shell tools or additional CLI dependencies are needed.
List<String> testServicesArguments(Directory server, List<String> arguments) {
  var current = server.absolute;
  while (true) {
    final config = File(
      p.join(current.path, '.dart_tool', 'package_config.json'),
    );
    if (config.existsSync()) {
      final entries =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      for (final entry in entries.cast<Map>()) {
        if (entry['name'] != 'dartway_core_server') continue;
        final root = config.uri.resolve(entry['rootUri'] as String);
        final script = File(
          p.join(root.toFilePath(), 'bin/dartway_test_services.dart'),
        );
        if (script.existsSync())
          return ['--packages=${config.path}', script.path, ...arguments];
      }
      break;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  throw const FormatException(
    'Resolve the server package with a framework version supporting external test servers.',
  );
}
