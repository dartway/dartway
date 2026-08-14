enum DwCheckSeverity { info, warning, error }

/// DartWay convention checks. Severity model:
/// - error — a convention is broken, fails the check (non-zero exit);
/// - warning — undesirable, should be looked at, does not fail the check;
/// - info — a nudge, purely informational.
enum DwCheckType {
  /// A file inside `ui_kit/` without the `part of '../ui_kit.dart'` directive.
  uiKitPartMissing,

  /// A text constant inside `ui_kit/` (texts belong to features/l10n).
  uiKitContainsText,

  /// Raw styles (Color/TextStyle/BorderRadius/theme access) outside `ui_kit/`.
  forbiddenUiUsage,

  /// Importing `ui_kit/*` files directly instead of the `ui_kit.dart` barrel.
  forbiddenUiKitImport,

  /// A feature folder with more than one root file. A subfolder other than
  /// `widgets/`/`logic/` is *not* reported here — it simply becomes a nested
  /// node of the tree, and is judged as a feature or a group on its own.
  invalidFeatureStructure,

  /// A file longer than 200 lines — a nudge, nothing more. A meaningful
  /// 300-line file beats a pointless split.
  fileLong,

  /// A file longer than 350 lines — worth restructuring: at that size a file
  /// has usually collected more than one responsibility.
  fileTooLong,

  /// Importing `widgets/` or `logic/` of another feature (only feature entry
  /// points are public).
  forbiddenFeatureImport,

  /// A feature whose public widget does not declare a `DwFeatureSpec` — the
  /// feature exists in the code but says nothing about itself, so error
  /// reports, Studio and the agent see it as a blank.
  featureSpecMissing,

  /// A folder in a zone whose entry point declares no widget. A zone holds
  /// features; a provider several features watch is wiring (`core/`), and a
  /// helper with no story of its own is a building block (`shared/`).
  ///
  /// The twin of [featureSpecMissing], and neither works without the other:
  /// while only widgets were asked for a spec, a folder that was not a widget
  /// passed *because* it was not one. A real project accumulated ten of them,
  /// every one graded A.
  notAFeature,

  /// An `assets/...` path that points at no file. Nothing else catches this:
  /// the code compiles and the screen renders a blank where the image was.
  assetPathMissing,

  /// A raw `assets/...` path outside `ui_kit/`. Asset paths live in one place
  /// in the kit — a path spelled out in a screen survives a renamed file only
  /// by accident, and cannot be found by search.
  forbiddenAssetPath,

  /// A file that only re-exports other files. It reads as convenience and acts
  /// as a hole in the feature boundary: importers name the barrel, so reaching
  /// into another feature's internals through it looks legitimate and the
  /// import checks see nothing. One such file laundered three features' guts
  /// until it was deleted.
  barrelFile,

  /// A file in a feature's `widgets/`/`logic/` that nothing in that feature
  /// references — dead code, and the kind that hides best: nobody outside the
  /// feature may import it, so the compiler is content and it survives every
  /// refactor. Checkable at all only because Law 3 closes the search to one
  /// folder; the analyzer cannot see it, since a public class is always
  /// "possibly used from elsewhere".
  unusedFeatureFile,

  /// `Expanded` or an infinite `SizedBox` as the root of `build` — the widget
  /// deciding how much room it gets. It works until someone puts it in a
  /// bottom sheet or a scroll view, and then it throws at runtime while the
  /// analyzer stays silent. Space is the parent's call.
  widgetSizesItself,

  /// A folder or file at the top level of a package that the declared layout
  /// does not name — or a fixed name that is missing. The top level is a
  /// closed list (`dwFlutterZones` / `dwFlutterLayers` / `dwServerAreas`), and
  /// it is closed because it had been declared in three places that drifted
  /// apart: an undeclared folder is where the next divergence starts.
  invalidTopLevelLayout,

  /// Generated code committed unformatted — the server's `lib/src/generated/`
  /// or the client's `lib/src/protocol/` differs from what `dart format`
  /// writes.
  ///
  /// `serverpod generate` formats its output with the `dart_style` bundled
  /// with the Serverpod CLI, which is not the `dart format` of the project's
  /// SDK. Leave the difference in place and every later generation rewrites
  /// files nobody touched: making one field nullable has arrived at review as
  /// 29 files and 1900 changed lines, with the two real lines unfindable
  /// inside it. The rule is therefore "both generated trees are committed
  /// formatted" — both, because formatting one of them only moves the diff to
  /// whoever next formats the other, which in one project meant 33 unrelated
  /// files landing in someone else's pull request.
  ///
  /// A **warning**, not an error, and deliberately so: the comparison is
  /// against the `dart_style` of whichever SDK ran the check, so a red result
  /// can mean "your SDK is newer than the one that formatted this" rather than
  /// "you skipped a step". Failing the build on that would make this the check
  /// people pass `--type` around to avoid. Hence the finding names the exact
  /// command and paths instead — the fix has to be runnable by someone who did
  /// not write the code and does not know why it went red.
  generatedCodeUnformatted;

  DwCheckSeverity get severity => switch (this) {
    DwCheckType.fileLong => DwCheckSeverity.info,
    DwCheckType.uiKitContainsText ||
    DwCheckType.featureSpecMissing ||
    DwCheckType.forbiddenAssetPath ||
    DwCheckType.unusedFeatureFile ||
    DwCheckType.generatedCodeUnformatted ||
    DwCheckType.fileTooLong => DwCheckSeverity.warning,
    _ => DwCheckSeverity.error,
  };

  String get reportLabel => switch (severity) {
    DwCheckSeverity.info => 'ℹ️ INFO',
    DwCheckSeverity.warning => '⚠️ WARNING',
    DwCheckSeverity.error => '❌ ERROR',
  };
}
