/// The client–server contract of the app, and the rules both sides apply
/// identically. Everything the app and the server exchange is declared here
/// and nowhere else.
library;

export 'package:dartway_core_shared/dartway_core_shared.dart';

export 'generated/dw_protocol.dart';
export 'src/admin.dart';
export 'src/auth_identifier.dart';
export 'src/dartway_starter_channel.dart';
export 'src/dartway_starter_refusal.dart';
export 'src/dartway_starter_upload.dart';
export 'src/profile.dart';
export 'src/registration_keys.dart';
export 'src/settings.dart';
