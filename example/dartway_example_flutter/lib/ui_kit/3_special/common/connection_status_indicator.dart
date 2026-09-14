part of '../../ui_kit.dart';

/// Live connection indicator over `dw.liveStatus`. Calls go over HTTP whatever
/// it says; what it tells is whether the data on screen follows the server:
/// only while "online". Idle means nothing on screen is live, so nothing is
/// missed. A server this build cannot talk to is not coming back: it says so.
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dw.liveStatus);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: _statusColor(status)),
          const SizedBox(width: 6),
          Text(switch (status) {
            DwConnectionStatus.connected ||
            DwConnectionStatus.idle => l10n.connectionOnline,
            DwConnectionStatus.connecting => l10n.connectionConnecting,
            DwConnectionStatus.disconnected => l10n.connectionOffline,
            DwConnectionStatus.incompatible => l10n.connectionIncompatible,
          }),
        ],
      ),
    );
  }

  Color _statusColor(DwConnectionStatus status) => switch (status) {
    DwConnectionStatus.connected || DwConnectionStatus.idle => Colors.green,
    DwConnectionStatus.connecting => Colors.orange,
    DwConnectionStatus.disconnected ||
    DwConnectionStatus.incompatible => Colors.red,
  };
}
