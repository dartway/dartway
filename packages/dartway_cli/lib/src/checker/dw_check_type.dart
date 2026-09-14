enum DwCheckSeverity { info, warning, error }

/// DartWay convention checks. Severity model:
/// - error — a convention is broken, fails the check (non-zero exit);
/// - warning — undesirable, should be looked at, does not fail the check;
/// - info — a nudge, purely informational.
enum DwCheckType {
  /// A file inside `ui_kit/` without the `part of '../ui_kit.dart'` directive.
  uiKitPartMissing,

  /// The app's localization is not wired: `flutter_localizations`,
  /// `generate: true`, `l10n.yaml` and a `.arb` catalogue.
  ///
  /// An error, because the law's own wording about it is "the first thing
  /// fixed, not something to live with". It is the one convention that cannot
  /// be broken by writing bad code — only by never having had it, which is the
  /// state a project reaching this methodology from elsewhere arrives in. And
  /// nothing else notices: the compiler is happy, the tests pass, and the app
  /// looks finished until somebody sees one item of a menu in the wrong
  /// language.
  l10nNotWired,

  /// A text constant inside `ui_kit/` (texts belong to features/l10n).
  uiKitContainsText,

  /// Raw styles (Color/TextStyle/BorderRadius/theme access) outside `ui_kit/`.
  forbiddenUiUsage,

  /// A `static const Color` or `static const TextStyle` inside `ui_kit/`,
  /// outside the folder where the theme is assembled.
  ///
  /// A token declared const does not depend on a context, so `ThemeData`
  /// changing does not touch it: the theme switches and the kit stays as it
  /// was. Nothing diagnoses that — the analyzer is quiet, this checker used to
  /// be quiet, the tests are green — and it surfaces on the day somebody asks
  /// for a light theme, as a rewrite of every token read in the kit.
  ///
  /// A warning rather than an error: the kit still works, and one theme is a
  /// legitimate state for a project to be in. What it will not survive is the
  /// second one.
  uiKitConstStyle,

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
  /// closed list (`dwFlutterZones` / `dwFlutterLayers` / `dwServerLibFolders`), and
  /// it is closed because it had been declared in three places that drifted
  /// apart: an undeclared folder is where the next divergence starts.
  invalidTopLevelLayout,

  /// Generated code that no longer matches its sources: a `*.dw.dart` part,
  /// the protocol registry or the schema that `dartway generate` would write
  /// differently, or a generated file whose source is gone —
  /// `dart run dartway_generator --check` in the server package.
  ///
  /// An error, with no second reading: the codecs are the wire. A data object
  /// with a field its generated part does not know compiles, starts and
  /// travels without that field, and a request missing from the registry is
  /// refused as unknown by a server that has its handler.
  generatedCodeStale,

  /// Migrations that do not produce the schema the row classes declare, a
  /// migration edited after its checksum was sealed or left unregistered, or
  /// a down that does not undo its up — `dart run bin/migrate.dart check` in
  /// the server package.
  ///
  /// It needs a Postgres to replay the migrations on (`DW_DATABASE_*`, where
  /// it creates and drops throwaway databases); without one the check says it
  /// did not run rather than passing. An error: a schema the migrations do not
  /// produce is a server that refuses to start in the next environment.
  migrationsDrift,

  /// The project's `dartway_*` git dependencies are locked to more than one
  /// commit of the framework. Nothing else says so: `ref: master` is written
  /// once per package and reads as "from master", while the lock pins each one
  /// at whatever master was when *that* package was added.
  frameworkRefsDiverged;

  /// Which severity a check carries, and the answer is read elsewhere.
  ///
  /// The `error` set is published as the law list in `toolkit/CLAUDE.md` — the
  /// rules a project on this framework may not override, as against the
  /// defaults it may. That is deliberately derived rather than sorted by hand:
  /// a check that declines to fail because it has a second legitimate reading
  /// is not something a project can be forbidden to decide for itself.
  ///
  /// So moving a check across this boundary moves it in or out of the law, and
  /// `toolkit_law_list_test.dart` holds the two together.
  DwCheckSeverity get severity => switch (this) {
    DwCheckType.fileLong => DwCheckSeverity.info,
    DwCheckType.uiKitContainsText ||
    DwCheckType.uiKitConstStyle ||
    DwCheckType.featureSpecMissing ||
    DwCheckType.forbiddenAssetPath ||
    DwCheckType.unusedFeatureFile ||
    DwCheckType.frameworkRefsDiverged ||
    DwCheckType.fileTooLong => DwCheckSeverity.warning,
    _ => DwCheckSeverity.error,
  };

  String get reportLabel => switch (severity) {
    DwCheckSeverity.info => 'ℹ️ INFO',
    DwCheckSeverity.warning => '⚠️ WARNING',
    DwCheckSeverity.error => '❌ ERROR',
  };
}
