part of '../../ui_kit.dart';

/// Live realtime-connection indicator built directly on the framework's public
/// `DwSocketService.statusNotifier`. Reacts to reconnects without leaking
/// connection errors into the app's error handler.
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = dw.socketService;
    if (socket == null) return const SizedBox.shrink();

    return ValueListenableBuilder<DwSocketStatus>(
      valueListenable: socket.statusNotifier,
      builder: (context, status, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: _statusColor(status)),
            const SizedBox(width: 6),
            Text(_statusLabel(status)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DwSocketStatus status) => switch (status) {
    DwSocketStatus.connected => Colors.green,
    DwSocketStatus.waitingToRetry => Colors.orange,
    // Nothing is subscribed, so there is nothing to be offline about.
    DwSocketStatus.idle => Colors.grey,
  };

  String _statusLabel(DwSocketStatus status) => switch (status) {
    DwSocketStatus.connected => 'online',
    DwSocketStatus.waitingToRetry => 'reconnecting',
    DwSocketStatus.idle => 'idle',
  };
}
