import '../core/dw_core.dart';

DwCore? _instance;

/// The initialized [DwCore] — the single `dw` root on the server, mirroring the
/// Flutter side's `dw`. One access style across the whole stack: `dw.advisoryLock`,
/// `dw.alerts`, `dw.getCrudConfig(...)` in the framework and in the app alike.
DwCore get dw {
  final instance = _instance;
  if (instance == null) throw StateError('DwCore is not initialized');
  return instance;
}

void setDwInstance(DwCore instance) {
  if (_instance != null) throw StateError('DwCore already initialized');
  _instance = instance;
}
