part of '../ui_kit.dart';

/// The app's theme. It lives in the kit because the kit is where styles live —
/// the app root only mounts it (`MaterialApp(theme: AppTheme.light)`).
///
/// Everything the whole app should look like once — button shapes, the colours
/// of the bottom bar — belongs here rather than in the widgets that happen to
/// use it. A colour set on the widget is a colour the next screen will forget.
abstract final class AppTheme {
  static const Color _seed = Color.fromARGB(255, 4, 49, 57);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed);

    return ThemeData(
      colorScheme: colorScheme,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.outline,
      ),
    );
  }
}
