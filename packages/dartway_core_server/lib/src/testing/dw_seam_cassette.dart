import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../outbound/dw_outbound_http.dart';
import '../process/dw_process_runner.dart';

/// A package-local recording of real external exchanges. Replay is offline.
/// Set `DW_RECORD_SEAMS=1` to replace a recording; `DW_VERIFY_SEAMS=1` calls
/// the real service and compares response shapes without changing the file.
/// Attach with `server.http.useCassette` / `server.process.useCassette`.
///
/// Files must live under the current package's `test/`. One file belongs to
/// one test; do not write it from concurrently running tests. Review recorded
/// files before committing. Add provider-specific secret names and values,
/// especially credentials in URL paths or positional command arguments.
final class DwSeamCassette {
  DwSeamCassette(
    String path, {
    List<String> redactNames = const [],
    List<String> redactValues = const [],
    Map<String, String>? environment,
  }) : _file = File(path),
       _redactor = _Redactor(redactNames, redactValues) {
    final testRoot = Directory('test').absolute.resolveSymbolicLinksSync();
    final parent = _file.absolute.parent;
    var ancestor = parent;
    while (!ancestor.existsSync()) {
      ancestor = ancestor.parent;
    }
    final existing = ancestor.resolveSymbolicLinksSync();
    if (existing != testRoot &&
        !existing.startsWith('$testRoot${Platform.pathSeparator}')) {
      throw ArgumentError(
        'A seam cassette must be under the package test/ directory',
      );
    }
    parent.createSync(recursive: true);
    final resolved = parent.resolveSymbolicLinksSync();
    if (!resolved.startsWith('$testRoot${Platform.pathSeparator}') &&
        resolved != testRoot) {
      throw ArgumentError(
        'A seam cassette must be under the package test/ directory',
      );
    }
    if (_file.existsSync() &&
        _file.resolveSymbolicLinksSync() !=
            '$resolved${Platform.pathSeparator}${_file.uri.pathSegments.last}') {
      throw ArgumentError('A seam cassette must not be a symbolic link');
    }
    final env = environment ?? Platform.environment;
    _record = env['DW_RECORD_SEAMS'] == '1';
    _verify = env['DW_VERIFY_SEAMS'] == '1';
    if (_record && _verify) {
      throw ArgumentError('Choose record or verify, not both');
    }
    if (!_record) {
      if (!_file.existsSync()) throw StateError('Missing seam cassette: $path');
      final data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw FormatException('Unsupported seam cassette version');
      }
      _entries.addAll((data['exchanges'] as List).cast<Map<String, dynamic>>());
    }
  }

  final File _file;
  final _Redactor _redactor;
  final _entries = <Map<String, dynamic>>[];
  final _used = <int>{};
  late final bool _record;
  late final bool _verify;

  Future<Map<String, dynamic>> _exchange(
    String kind,
    Map<String, Object?> request,
    Future<Map<String, Object?>> Function() real,
  ) async {
    final safeRequest = _redactor.clean(request);
    if (_record) {
      final response = await real();
      // Discover response secrets before writing either side (including echoes).
      final pair =
          _redactor.clean({'request': request, 'response': response}) as Map;
      final entry = <String, dynamic>{
        'kind': kind,
        ...pair.cast<String, dynamic>(),
      };
      _entries.add(entry);
      final temporary = File('${_file.path}.tmp');
      temporary.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'exchanges': _entries})}\n',
      );
      temporary.renameSync(_file.path);
      return response;
    }
    final key = _canonical(safeRequest);
    var index = -1;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!_used.contains(i) &&
          entry['kind'] == kind &&
          _canonical(entry['request']) == key) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      throw StateError(
        'No seam cassette answer in ${_file.path}: $kind ${jsonEncode(safeRequest)}',
      );
    }
    _used.add(index);
    final saved = (_entries[index]['response'] as Map).cast<String, dynamic>();
    if (_verify) {
      final response = await real();
      if (_canonical(_responseShape(_redactor.clean(response) as Map)) !=
          _canonical(_responseShape(saved))) {
        throw StateError(
          'Seam drift in ${_file.path}: $kind ${jsonEncode(safeRequest)}; '
          'expected ${jsonEncode(_responseShape(saved))}, got ${jsonEncode(_responseShape(response))}',
        );
      }
      return response;
    }
    return saved;
  }

  /// Every recorded exchange must be exercised, including repeated requests.
  void verifyComplete() {
    if (!_record && _used.length != _entries.length) {
      throw StateError(
        'Unused exchanges in ${_file.path}: ${_entries.length - _used.length}',
      );
    }
  }

  /// Rewinds replay for another execution of the same feature.
  void rewind() => _used.clear();

  @internal
  Future<DwOutboundResponse> http(
    DwOutboundRequest request,
    Duration timeout,
    int maxBytes,
  ) async {
    final response = await _exchange(
      'http',
      {
        'method': request.method,
        'url': request.url.toString(),
        'headers': request.headers,
        'body': _body(
          request.bodyBytes,
          contentType: request.headers['content-type'],
        ),
        'followRedirects': request.followRedirects,
      },
      () async {
        final transport = DwNetworkTransport(connectionTimeout: timeout);
        try {
          final answer = await transport.exchange(request, timeout, maxBytes);
          return {
            'statusCode': answer.statusCode,
            'headers': answer.headers,
            'body': _body(
              answer.bodyBytes,
              contentType: answer.headers['content-type'],
            ),
          };
        } finally {
          transport.close();
        }
      },
    );
    return DwOutboundResponse(
      response['statusCode'] as int,
      headers: (response['headers'] as Map).cast<String, String>(),
      body: _bytes(response['body'] as Map),
    );
  }

  @internal
  Future<DwProcessResult> process(
    DwProcessRequest request,
    Duration timeout,
    int maxBytes,
  ) async {
    final response = await _exchange(
      'process',
      {
        'executable': request.executable,
        'arguments': request.arguments,
        'workingDirectory': request.workingDirectory,
        'environment': request.environment,
      },
      () async {
        final answer = await const DwSystemProcess().run(
          request,
          timeout,
          maxBytes,
        );
        return {
          'exitCode': answer.exitCode,
          'stdout': _text(answer.stdout),
          'stderr': _text(answer.stderr),
        };
      },
    );
    return DwProcessResult(
      response['exitCode'] as int,
      _string(response['stdout'] as Map),
      _string(response['stderr'] as Map),
    );
  }
}

Map<String, Object?> _text(String text) {
  try {
    return {'json': jsonDecode(text)};
  } on FormatException {
    return {'text': text};
  }
}

Map<String, Object?> _body(List<int> bytes, {String? contentType}) {
  if (contentType?.startsWith('application/x-www-form-urlencoded') ?? false) {
    return {'form': Uri.splitQueryString(utf8.decode(bytes))};
  }
  try {
    return _text(utf8.decode(bytes));
  } on FormatException {
    return {'base64': base64Encode(bytes)};
  }
}

String _string(Map value) => value.containsKey('json')
    ? jsonEncode(value['json'])
    : value['text'] as String;
List<int> _bytes(Map value) => value.containsKey('form')
    ? utf8.encode(
        Uri(
          queryParameters: (value['form'] as Map).cast<String, String>(),
        ).query,
      )
    : value.containsKey('base64')
    ? base64Decode(value['base64'] as String)
    : utf8.encode(_string(value));

// Status values belong only to the transport envelope. Provider JSON may
// contain fields with these same names; their scalar values are not a shape.
Object? _responseShape(Map value) => {
  for (final entry in value.entries)
    entry.key: entry.key == 'statusCode' || entry.key == 'exitCode'
        ? entry.value
        : _shape(entry.value),
};

Object? _shape(Object? value) {
  if (value is Map) {
    return {for (final entry in value.entries) entry.key: _shape(entry.value)};
  }
  if (value is List) {
    return (value.map((item) => _canonical(_shape(item))).toSet().toList()
      ..sort());
  }
  return switch (value) {
    null => 'null',
    bool() => 'bool',
    num() => 'number',
    String() => 'string',
    _ => throw FormatException('Not JSON'),
  };
}

String _canonical(Object? value) => jsonEncode(_sorted(value));
Object? _sorted(Object? value) {
  if (value is Map) {
    return {
      for (final key in value.keys.cast<String>().toList()..sort())
        key: _sorted(value[key]),
    };
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

final class _Redactor {
  _Redactor(List<String> names, List<String> values)
    : names = names.map(_name).toSet(),
      values = {...values.where((value) => value.isNotEmpty)};
  final Set<String> names;
  final Set<String> values;
  static String _name(String name) =>
      name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  bool sensitive(String key) {
    final name = _name(key);
    return names.contains(name) ||
        name.endsWith('token') ||
        name == 'tokens' ||
        name.endsWith('apikey') ||
        [
          'authorization',
          'cookie',
          'secret',
          'password',
          'credential',
        ].any(name.contains);
  }

  void discover(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (sensitive(entry.key as String)) {
          void remember(Object? item) {
            if (item is String && item.isNotEmpty) {
              values.add(item);
              if (item.startsWith('Bearer ') || item.startsWith('Basic ')) {
                values.add(item.split(' ').last);
              }
            } else if (item is Map) {
              item.values.forEach(remember);
            } else if (item is List) {
              item.forEach(remember);
            }
          }

          remember(entry.value);
        } else {
          discover(entry.value);
        }
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is String && item.startsWith('-')) {
          final parts = item.split('=');
          if (sensitive(parts.first)) {
            final secret = parts.length > 1
                ? parts.skip(1).join('=')
                : (i + 1 < value.length ? value[i + 1] : null);
            if (secret is String && secret.isNotEmpty) values.add(secret);
          }
        }
      }
      value.forEach(discover);
    } else if (value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.hasScheme) {
        if (uri.userInfo.isNotEmpty) values.add(uri.userInfo);
        for (final entry in uri.queryParametersAll.entries) {
          if (sensitive(entry.key)) {
            values.addAll(entry.value.where((v) => v.isNotEmpty));
          }
        }
      }
    }
  }

  Object? clean(Object? value) {
    discover(value);
    return replace(value);
  }

  Object? replace(Object? value, {bool structured = false}) {
    if (value is Map) {
      if (!structured && value.length == 1 && value['base64'] is String) {
        final bytes = latin1.decode(base64Decode(value['base64'] as String));
        return {
          'base64': base64Encode(latin1.encode(replace(bytes) as String)),
        };
      }
      return {
        for (final entry in value.entries)
          entry.key: sensitive(entry.key as String)
              ? _masked(entry.value)
              : replace(
                  entry.value,
                  structured:
                      structured || entry.key == 'json' || entry.key == 'form',
                ),
      };
    }
    if (value is List) {
      return value
          .map((item) => replace(item, structured: structured))
          .toList();
    }
    if (value is String) {
      var safe = value;
      for (final secret
          in values.toList()..sort((a, b) => b.length.compareTo(a.length))) {
        safe = safe
            .replaceAll(secret, '[REDACTED]')
            .replaceAll(Uri.encodeComponent(secret), '[REDACTED]')
            .replaceAll(Uri.encodeQueryComponent(secret), '[REDACTED]');
      }
      return safe;
    }
    return value;
  }
}

// Keep the recorded JSON decodable after redaction. Credential values change;
// their types and container structure remain the provider's real contract.
Object? _masked(Object? value) => switch (value) {
  null => null,
  String() => '[REDACTED]',
  bool() => false,
  int() => 0,
  double() => 0.0,
  List() => value.map(_masked).toList(),
  Map() => {for (final entry in value.entries) entry.key: _masked(entry.value)},
  _ => throw FormatException('Not JSON'),
};
