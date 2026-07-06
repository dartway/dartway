part of '../../ui_kit.dart';

/// Style tokens of the showcase chrome. The chrome is a presentation wrapper
/// and is deliberately visually distinct from the app inside the device frame.
abstract final class ShowcaseChrome {
  static const background = Color(0xFF11161C);
  static const panelColor = Color(0xFF1A222B);
  static const chipColor = Color(0xFF232E39);
  static const chipActiveColor = Color(0xFF3E6B64);
  static const accentColor = Color(0xFF63D6C5);
  static const textColor = Color(0xFFE7EDF2);
  static const mutedColor = Color(0xFF8B98A5);

  static const panelWidth = 380.0;

  static const brandTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: accentColor,
  );
  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textColor,
  );
  static const sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: mutedColor,
  );
  static const bodyText = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: textColor,
  );
  static const chipLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textColor,
  );
  static const captionText = TextStyle(fontSize: 12, color: mutedColor);

  static BorderRadius get chipRadius => BorderRadius.circular(999);
  static BorderRadius get cardRadius => BorderRadius.circular(12);
}
