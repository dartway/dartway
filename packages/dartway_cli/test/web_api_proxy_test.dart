import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final repository = _repositoryRoot();
  final templateScript = File(
    p.join(
      repository.path,
      'template/dartway_starter_flutter/docker-entrypoint.d/'
          '20-dartway-api-proxy.sh',
    ),
  ).readAsStringSync();
  final exampleScript = File(
    p.join(
      repository.path,
      'example/dartway_example_flutter/docker-entrypoint.d/'
          '20-dartway-api-proxy.sh',
    ),
  ).readAsStringSync();

  test('template and example install the same proxy entrypoint', () {
    expect(exampleScript, templateScript);
  });

  test('entrypoint leaves an empty include without Kamal environment', () {
    final run = _runScript(templateScript);
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(run.output.readAsStringSync(), isEmpty);
  });

  test('entrypoint renders API, health, route and live socket proxies', () {
    final run = _runScript(
      templateScript,
      environment: {
        'DW_API_ORIGIN': 'https://api.example.com:8443',
        'DW_API_PATHS': '/dw /health /orders/events',
      },
    );
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final rendered = run.output.readAsStringSync();
    expect(rendered, contains('location ^~ /dw/'));
    expect(rendered, contains('proxy_http_version 1.1'));
    expect(rendered, contains(r'proxy_set_header Upgrade $http_upgrade'));
    expect(rendered, contains('proxy_buffering off'));
    expect(rendered, contains('proxy_read_timeout 1h'));
    expect(rendered, contains('location ^~ /health'));
    expect(rendered, contains('location ^~ /orders/events'));
    expect(rendered, contains('proxy_pass https://api.example.com:8443'));
    expect(rendered, contains('proxy_set_header Host api.example.com:8443'));
    expect(rendered, contains(r'X-Forwarded-For $proxy_add_x_forwarded_for'));
    expect(rendered, contains(r'X-Forwarded-Proto $http_x_forwarded_proto'));
  });

  for (final environment in [
    {'DW_API_ORIGIN': 'http://api.example.com', 'DW_API_PATHS': '/dw'},
    {'DW_API_ORIGIN': 'https://api.example.com/path', 'DW_API_PATHS': '/dw'},
    {
      'DW_API_ORIGIN': 'https://api.example.com',
      'DW_API_PATHS': '/dw relative',
    },
  ]) {
    test('entrypoint rejects invalid proxy environment $environment', () {
      final run = _runScript(templateScript, environment: environment);
      expect(run.result.exitCode, isNot(0));
      expect(run.result.stderr, isNotEmpty);
    });
  }
}

({ProcessResult result, File output}) _runScript(
  String source, {
  Map<String, String> environment = const {},
}) {
  final directory = Directory.systemTemp.createTempSync('web-api-proxy-');
  addTearDown(() => directory.deleteSync(recursive: true));
  final output = File(p.join(directory.path, 'proxy.inc'));
  final script = File(p.join(directory.path, 'entrypoint.sh'))
    ..writeAsStringSync(
      source.replaceFirst(
        'output=/etc/nginx/conf.d/dartway-api-proxy.inc',
        "output='${output.path}'",
      ),
    );
  final result = Process.runSync('sh', [script.path], environment: environment);
  return (result: result, output: output);
}

Directory _repositoryRoot() {
  var directory = Directory.current.absolute;
  while (!Directory(p.join(directory.path, 'template')).existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('no template directory above ${Directory.current.path}');
    }
    directory = parent;
  }
  return directory;
}
