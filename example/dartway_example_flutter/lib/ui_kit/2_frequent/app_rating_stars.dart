part of '../ui_kit.dart';

/// A row of stars, tappable or not.
///
/// It lives in the kit for the reason the kit exists: an [Icon] wants a
/// [Color], not a widget, so a feature that draws its own stars ends up reaching
/// for the theme — and the style escapes. When Flutter demands a style, the
/// whole widget moves in here, and the feature is left composing.
class AppRatingStars extends StatelessWidget {
  const AppRatingStars({required this.rating, super.key, this.onRatingChanged});

  /// How many stars are filled, 1..[maxRating].
  final int rating;

  /// When null, the stars are read-only.
  final ValueChanged<int>? onRatingChanged;

  static const int maxRating = 5;

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final icon = Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: color,
        );

        if (onRatingChanged == null) return icon;

        return IconButton(
          onPressed: () => onRatingChanged!(index + 1),
          icon: icon,
        );
      }),
    );
  }
}
