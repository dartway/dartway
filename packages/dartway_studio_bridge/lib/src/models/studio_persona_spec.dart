/// A demo persona the app can sign in on Studio's request.
///
/// The sign-in mechanics (dev OTP codes, auth flow) stay entirely inside the
/// app — Studio only ever asks for a persona by [id].
class StudioPersonaSpec {
  const StudioPersonaSpec({
    required this.id,
    required this.label,
    required this.identifier,
  });

  /// Stable id Studio sends back in a persona request.
  final String id;

  /// Human-readable label for the persona menu, e.g. `Client · Ivan`.
  final String label;

  /// The app-side sign-in identifier (e.g. a seeded phone number). Exposed so
  /// the app can match the active session back to a persona.
  final String identifier;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'identifier': identifier,
      };

  factory StudioPersonaSpec.fromJson(Map<String, dynamic> json) =>
      StudioPersonaSpec(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        identifier: json['identifier'] as String? ?? '',
      );
}
