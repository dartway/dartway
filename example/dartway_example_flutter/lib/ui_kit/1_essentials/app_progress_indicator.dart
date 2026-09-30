part of '../ui_kit.dart';

/// Something under way: a read loading (the app's
/// `DwFlutterConfig.readLoadingBuilder`), an upload, a wait the screen owns.
///
/// The kit's one spinner, so its look is decided once: `dartway check` refuses
/// `CircularProgressIndicator` outside `ui_kit/` (`forbiddenProgressIndicator`).
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({this.value, this.size, super.key});

  /// The share done, 0 to 1; `null` while it is not known.
  final double? value;

  /// The diameter; the platform's own when `null`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      value: value,
      strokeWidth: size != null && size! < 32 ? 2 : 4,
    );
    return size == null
        ? indicator
        : SizedBox.square(dimension: size, child: indicator);
  }
}
