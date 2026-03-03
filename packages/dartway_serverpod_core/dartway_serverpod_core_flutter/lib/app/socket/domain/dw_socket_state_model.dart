import 'package:serverpod_client/serverpod_client.dart';

class DwSocketStateModel {
  final StreamingConnectionStatus websocketStatus;

  const DwSocketStateModel({required this.websocketStatus});

  DwSocketStateModel copyWith({StreamingConnectionStatus? websocketStatus}) {
    return DwSocketStateModel(
      websocketStatus: websocketStatus ?? this.websocketStatus,
    );
  }
}
