part of '../ui_kit.dart';

/// Draws an [AppIcon]. The single place in the app that calls `Image.asset`
/// or `SvgPicture.asset` — a screen receives a widget, not a file name.
///
/// One [size], not width and height: an icon keeps its own proportions, and a
/// separate width and height is almost always the wrong asset rather than a
/// deliberate stretch. Something that has to fill a box is not an icon —
/// that is a cover, and it gets its own widget.
class AppIconView extends StatelessWidget {
  const AppIconView(this.icon, {super.key, this.size});

  final AppIcon icon;

  /// The side of the square the icon is drawn into. `null` — natural size.
  final double? size;

  @override
  Widget build(BuildContext context) => icon.isVector
      ? SvgPicture.asset(icon.path, width: size, height: size)
      : Image.asset(icon.path, width: size, height: size);
}
