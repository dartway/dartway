/// Open bridge between a DartWay app and DartWay Studio: in-code screen spec
/// registry models and the runtime postMessage protocol.
library;

// Spec models (declared in the app's code, delivered to Studio on connect).
export 'src/models/studio_feature_info.dart';
export 'src/models/studio_manifest_index.dart';
export 'src/models/studio_project_manifest.dart';
export 'src/models/studio_screen_spec.dart';
export 'src/models/studio_session_state.dart';
export 'src/models/studio_zone_spec.dart';

// Runtime protocol.
export 'src/protocol/studio_bridge_message.dart';
export 'src/protocol/studio_bridge_protocol.dart';

// Access control (shared hashing + a ready-made validator).
export 'src/access/studio_access_key.dart';

// App side.
export 'src/host/studio_bridge_host.dart';

// Studio side.
export 'src/client/studio_bridge_client.dart';
export 'src/client/studio_bridge_event.dart';
export 'src/transport/client/studio_frame_controller.dart';
export 'src/transport/studio_message_channel.dart';
