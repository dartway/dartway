/// Fixed dev OTP accepted by the example server in development run mode.
/// Keep in sync with _devVerificationCode in
/// dartway_example_server/lib/src/dartway/dartway_core.dart.
const showcaseDevOtpCode = '000000';

/// Seeded demo users (see dartway_example_server/bin/seed_dev.dart).
enum ShowcasePersona {
  clientIvan('79990000003', 'Client · Ivan'),
  coachMaria('79990000002', 'Coach · Maria'),
  adminAlex('79990000001', 'Admin · Alex');

  const ShowcasePersona(this.phone, this.displayLabel);

  final String phone;
  final String displayLabel;
}
