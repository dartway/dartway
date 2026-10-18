import 'dart:ui' as ui;

import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bundled logo shows the violet cube on a transparent background',
    () async {
      final asset = await rootBundle.load(AppIcon.logo.path);
      final codec = await ui.instantiateImageCodec(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
        targetWidth: 168,
        targetHeight: 188,
      );
      addTearDown(codec.dispose);
      final frame = await codec.getNextFrame();
      addTearDown(frame.image.dispose);
      final pixels = (await frame.image.toByteData())!;

      // Interior points of the faces in the source SVG's viewBox (16 1 168 188).
      // Avoid antialiased edges so the check is independent of the rasterizer.
      for (final (x, y, rgba) in [
        (60, 40, 0xc799f1ff),
        (140, 40, 0xc799f1ff),
        (40, 80, 0x9f52e7ff),
        (160, 80, 0x9f52e7ff),
        (60, 140, 0xb376ecff),
        (140, 140, 0xb376ecff),
      ]) {
        expect(
          pixels.getUint32(((y - 1) * 168 + x - 16) * 4),
          rgba,
          reason: 'cube face at ($x, $y)',
        );
      }
      for (final (x, y) in [(0, 0), (167, 0), (0, 187), (167, 187), (84, 94)]) {
        expect(
          pixels.getUint8((y * 168 + x) * 4 + 3),
          0,
          reason: 'transparent background or central gap at ($x, $y)',
        );
      }
    },
  );
}
