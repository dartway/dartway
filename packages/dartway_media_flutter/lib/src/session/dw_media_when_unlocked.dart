part of 'dw_media_session_manager.dart';

/// Runs [write] now, or after the frame when the widget tree is locked — a
/// `State.dispose`, a build — where a notifier with listening widgets must
/// not change.
void _whenUnlocked(VoidCallback write) {
  final scheduler = SchedulerBinding.instance;
  if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    scheduler.addPostFrameCallback((_) => write());
    return;
  }
  write();
}
