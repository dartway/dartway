import 'package:dartway_cli/src/test_storage.dart';
import 'package:test/test.dart';

void main() {
  test('the storage of a test run is stated in the names the server and '
      'DwTestStorage read — endpoint and keys, no buckets', () {
    const storage = EphemeralStorage(id: 'abc', port: 49152, secretKey: 's');
    expect(storage.storageEnvironment(), {
      'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:49152',
      'DW_STORAGE_ACCESS_KEY': TestStorage.accessKey,
      'DW_STORAGE_SECRET_KEY': 's',
    });
  });
}
