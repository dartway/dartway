import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwMediaSource', () {
    test('.url resolves to the given URI without calling anything', () async {
      final source = DwMediaSource.url('https://example.com/a.mp4');
      expect(await source.resolve(), Uri.parse('https://example.com/a.mp4'));
    });

    test('.resolve calls the resolver every time — twice for two resolve()s', () async {
      var calls = 0;
      final source = DwMediaSource.resolve(() async {
        calls++;
        return Uri.parse('https://example.com/signed-$calls.mp4');
      });
      final first = await source.resolve();
      final second = await source.resolve();
      expect(calls, 2);
      expect(first, Uri.parse('https://example.com/signed-1.mp4'));
      expect(second, Uri.parse('https://example.com/signed-2.mp4'));
    });
  });

  group('DwMediaItem', () {
    test('equality and hashCode are by id alone', () {
      final a = DwMediaItem(
        id: 'x',
        kind: DwMediaKind.video,
        source: const DwMediaSource.url('https://example.com/a.mp4'),
        title: 'A',
      );
      final b = DwMediaItem(
        id: 'x',
        kind: DwMediaKind.video,
        source: const DwMediaSource.url('https://example.com/different.mp4'),
        title: 'Something else entirely',
      );
      final c = DwMediaItem(
        id: 'y',
        kind: DwMediaKind.video,
        source: const DwMediaSource.url('https://example.com/a.mp4'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
