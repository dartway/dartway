import 'dart:async';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:test/test.dart';

void main() {
  test('S3 requests reach an explicit IPv6 loopback endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv6, 0);
    addTearDown(() => server.close(force: true));
    final request = Completer<HttpRequest>();
    server.listen(request.complete);
    final port = server.port;
    final store = DwObjectStore(
      DwFileStorageConfig(
        endpoint: Uri(scheme: 'http', host: '::1', port: port),
        accessKey: 'test-key',
        secretKey: 'test-secret',
      ),
      requestTimeout: const Duration(seconds: 5),
    );
    addTearDown(store.close);
    final response = store.send('GET', bucket: 'test-bucket', key: 'some file');
    final received = await request.future.timeout(const Duration(seconds: 5));
    expect(received.headers.value(HttpHeaders.hostHeader), '[::1]:$port');
    expect(received.uri.pathSegments, ['test-bucket', 'some file']);
    await received.response.close();
    await (await response).drain<void>();
  });
}
