import 'package:dartway_cli/src/pub_host.dart';
import 'package:test/test.dart';

void main() {
  group('pubHostProbeUri', () {
    test('falls back to pub.dev when nothing is configured', () {
      expect(pubHostProbeUri(null).host, 'pub.dev');
      expect(pubHostProbeUri('').host, 'pub.dev');
      expect(pubHostProbeUri('   ').host, 'pub.dev');
    });

    test('asks pub.dev for the package metadata API', () {
      expect(
        pubHostProbeUri(null).toString(),
        'https://pub.dev/api/packages/dartway_cli',
      );
    });

    test('probes the mirror PUB_HOSTED_URL names', () {
      expect(
        pubHostProbeUri('https://mirror.example').toString(),
        'https://mirror.example/api/packages/dartway_cli',
      );
    });

    test('keeps a mirror served from a path', () {
      // The case the helper exists for: resolving a relative segment against
      // this base would drop `/pub` and probe a host that may well answer while
      // the mirror behind it does not.
      expect(
        pubHostProbeUri('https://mirror.example/pub/').toString(),
        'https://mirror.example/pub/api/packages/dartway_cli',
      );
      expect(
        pubHostProbeUri('https://mirror.example/pub').toString(),
        'https://mirror.example/pub/api/packages/dartway_cli',
      );
    });

    test('tolerates surrounding whitespace and repeated slashes', () {
      expect(
        pubHostProbeUri('  https://mirror.example//  ').toString(),
        'https://mirror.example/api/packages/dartway_cli',
      );
    });
  });
}
