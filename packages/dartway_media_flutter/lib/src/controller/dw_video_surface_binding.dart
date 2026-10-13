import 'package:flutter/foundation.dart';

/// Internal lease notifications from a surface to its video engine.
@internal
abstract interface class DwVideoSurfaceBinding {
  void attachVideoSurface();
  void detachVideoSurface();
}
