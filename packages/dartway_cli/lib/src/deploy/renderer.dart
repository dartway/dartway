import 'dart:io';

import 'package:path/path.dart' as p;

import 'deploy_target.dart';
import 'serverpod_config.dart';
import 'templates.dart';

/// Renders the infrastructure files a deployment needs.
///
/// Values come from the Serverpod configuration wherever Serverpod has an
/// opinion, so a domain or port exists in exactly one place.
class DwInfraRenderer {
  DwInfraRenderer({
    required this.projectRoot,
    required this.target,
    required this.serverpod,
    required this.serverPackage,
    required this.flutterPackage,
  });

  final Directory projectRoot;
  final DwDeployTarget target;
  final DwServerpodConfig serverpod;
  final String serverPackage;
  final String flutterPackage;

  /// Compose pulls base images through this prefix when a mirror is set.
  String get _registryPrefix {
    final mirror = target.registryMirror;
    return mirror == null ? '' : '$mirror/';
  }

  Map<DwTemplateToken, String> get _values => {
    DwTemplateToken.serverpodEnv: target.environment,
    DwTemplateToken.serverPackage: serverPackage,
    DwTemplateToken.flutterPackage: flutterPackage,
    DwTemplateToken.runtimeConfigDir: target.runtimeConfigDir,
    DwTemplateToken.databaseName: serverpod.databaseName ?? '',
    DwTemplateToken.databaseUser: serverpod.databaseUser ?? '',
    DwTemplateToken.apiPort: '${serverpod.apiServer.port ?? 8080}',
    DwTemplateToken.insightsPort: '${serverpod.insightsServer?.port ?? 8081}',
    DwTemplateToken.webServerPort: '${serverpod.webServer?.port ?? 8082}',
    DwTemplateToken.apiDomain: serverpod.apiServer.publicHost ?? '',
    DwTemplateToken.insightsDomain: serverpod.insightsServer?.publicHost ?? '',
    DwTemplateToken.webServerDomain: serverpod.webServer?.publicHost ?? '',
    DwTemplateToken.webAppDomain: target.webAppDomain,
    // One certificate covers every domain of the environment; it is named
    // after the API host, which is the one guaranteed to exist.
    DwTemplateToken.certName: serverpod.apiServer.publicHost ?? '',
    DwTemplateToken.registryPrefix: _registryPrefix,
  };

  /// Replaces every token and refuses to return text that still holds one.
  ///
  /// A leftover `__TOKEN__` reaching a server produces an error far from its
  /// cause — a container that will not start, or an Nginx that serves the
  /// wrong host.
  String _render(String template) {
    var text = template;
    for (final entry in _values.entries) {
      text = text.replaceAll(entry.key.placeholder, entry.value);
    }
    final leftover = RegExp(r'__[A-Z_]+__').firstMatch(text);
    if (leftover != null) {
      throw StateError(
        'Template still holds ${leftover.group(0)} after rendering. '
        'Every placeholder must have a value.',
      );
    }
    return text;
  }

  String get composeFile {
    final buffer = StringBuffer(dwComposeTemplate);
    if (serverpod.managesRedis) {
      // Appended rather than always present: an unused Redis container is a
      // service to monitor, restart and explain for no reason.
      final marker = '\nvolumes:';
      final text = buffer.toString();
      final withRedis = text.replaceFirst(
        marker,
        '${dwComposeRedisService.trimRight()}\n$marker',
      );
      return _render(withRedis);
    }
    return _render(buffer.toString());
  }

  String get nginxFile => _render(dwNginxTemplate);

  /// Environment file consumed by Compose interpolation.
  ///
  /// Passwords land here rather than inside `docker-compose.yml` so the
  /// compose file itself carries no secret and can be read while debugging.
  String environmentFile({
    required String databasePassword,
    required String redisPassword,
  }) {
    final lines = [
      '# Rendered by "dartway deploy setup". Contains secrets; mode 0600.',
      'DB_PASSWORD=$databasePassword',
      if (serverpod.managesRedis) 'REDIS_PASSWORD=$redisPassword',
    ];
    return '${lines.join('\n')}\n';
  }

  File? get composeOverride {
    final file = File(
      p.join(projectRoot.path, 'deploy', 'compose.override.yml'),
    );
    return file.existsSync() ? file : null;
  }

  /// Extra Nginx snippets, keyed by their path under `deploy/nginx.d/`.
  Map<String, File> get nginxSnippets {
    final root = Directory(p.join(projectRoot.path, 'deploy', 'nginx.d'));
    if (!root.existsSync()) {
      return const {};
    }
    final snippets = <String, File>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.conf')) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll(r'\', '/');
      snippets[relative] = entity;
    }
    return snippets;
  }
}
