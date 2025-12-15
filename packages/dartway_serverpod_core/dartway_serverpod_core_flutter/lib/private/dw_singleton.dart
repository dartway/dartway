import 'package:dartway_serverpod_core_flutter/core/dw_core.dart';

DwCore? _instance;

DwCore get dw {
  final v = _instance;
  if (v == null) throw StateError('DwCore is not initialized');
  return v;
}

void setDwInstance(DwCore instance) {
  if (_instance != null) throw StateError('DwCore already initialized');
  _instance = instance;
}
