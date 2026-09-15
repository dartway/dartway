/// Testing push without credentials: a local service that speaks FCM's send
/// API and Google's OAuth token endpoint (verifying the RS256 assertion) and
/// RuStore's send API, records what it was sent and answers as a test says.
library;

export 'src/testing/dw_fake_push_service.dart';
