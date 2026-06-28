import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';

/// Live streaming-connection indicator built directly on the framework's public
/// `DwSocketService.statusNotifier`. Reacts to reconnects without leaking
/// connection errors into the app's error handler.
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = dw.socketService;
    if (socket == null) return const SizedBox.shrink();

    return ValueListenableBuilder<StreamingConnectionStatus>(
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

  Color _statusColor(StreamingConnectionStatus status) =>
      switch (status) {
        StreamingConnectionStatus.connected => Colors.green,
        StreamingConnectionStatus.connecting => Colors.orange,
        StreamingConnectionStatus.waitingToRetry => Colors.orange,
        StreamingConnectionStatus.disconnected => Colors.red,
      };

  String _statusLabel(StreamingConnectionStatus status) =>
      switch (status) {
        StreamingConnectionStatus.connected => 'online',
        StreamingConnectionStatus.connecting => 'connecting',
        StreamingConnectionStatus.waitingToRetry => 'reconnecting',
        StreamingConnectionStatus.disconnected => 'offline',
      };
}
