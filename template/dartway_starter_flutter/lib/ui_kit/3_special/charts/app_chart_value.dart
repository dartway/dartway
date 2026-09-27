part of '../../ui_kit.dart';

/// One value a chart shows: what it is called, and how much.
class AppChartValue {
  const AppChartValue(this.label, this.value);

  final String label;
  final num value;
}

/// The colours of a chart's series, from the theme: the primary colour and
/// hues spread from it by the golden angle, so neighbours never look alike
/// however many there are. The last slot of a chart that has a remainder
/// ("other") is the outline colour — a remainder is not a series.
extension AppChartColors on BuildContext {
  Color chartColor(int index) {
    final base = HSLColor.fromColor(colorScheme.primary);
    return base
        .withHue((base.hue + index * 137.508) % 360)
        .withSaturation(max(base.saturation, 0.45))
        .withLightness(base.lightness.clamp(0.35, 0.55))
        .toColor();
  }

  Color get chartRestColor => colorScheme.outline;
}
