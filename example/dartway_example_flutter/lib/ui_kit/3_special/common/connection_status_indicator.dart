part of '../../ui_kit.dart';

/// Live connection indicator over `dw.connectionStatus`. Data on screen
/// follows the server only while it reads "online"; meanwhile it shows what
/// was last loaded, and every watched read runs again on reconnect. A server
/// on another wire version is not coming back for this build: it says so.
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dw.connectionStatus);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: _statusColor(status)),
          const SizedBox(width: 6),
          Text(switch (status) {
            DwConnectionStatus.connected => l10n.connectionOnline,
            DwConnectionStatus.connecting => l10n.connectionConnecting,
            DwConnectionStatus.disconnected => l10n.connectionOffline,
            DwConnectionStatus.incompatible => l10n.connectionIncompatible,
          }),
        ],
      ),
    );
  }

  Color _statusColor(DwConnectionStatus status) => switch (status) {
    DwConnectionStatus.connected => Colors.green,
    DwConnectionStatus.connecting => Colors.orange,
    DwConnectionStatus.disconnected ||
    DwConnectionStatus.incompatible => Colors.red,
  };
}
