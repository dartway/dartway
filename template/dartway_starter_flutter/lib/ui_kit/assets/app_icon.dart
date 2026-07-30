part of '../ui_kit.dart';

/// The app's asset vocabulary: every file the UI can show, named once.
///
/// A screen names an icon, never a file — the path lives here and nowhere
/// else, so renaming a file is a one-line change, and `dartway check` can
/// prove every entry points at something that exists.
///
/// Both formats live in one list on purpose: [AppIconView] picks the renderer
/// by extension, so swapping a PNG for an SVG is an edit here rather than a
/// hunt through the screens.
enum AppIcon {
  /// The brand mark on the greeting screen — the first thing a new project
  /// replaces. Drop your own file in `assets/` and change the path here.
  brandMark('assets/dartway_mark.svg'),
  logo('assets/dartway_logo.png'),
  branding('assets/dartway_branding.png');

  const AppIcon(this.path);

  /// Public for the rare case that needs a raw path (precaching, a
  /// third-party widget) — and only inside the kit. A screen that spells out
  /// a path is what this enum exists to prevent.
  final String path;

  bool get isVector => path.endsWith('.svg');
}
