# Changelog

## 0.1.0

- First public release: `DwAppRunner` bootstrap, `dw` app core (navigation,
  notifications, services, shared preferences, plugins), overlay notifications
  pipeline, `DwInfiniteListView`, and AsyncValue utilities (`dwBuildListAsync`,
  `DwUiAction`).
- **The package ships no design system.** `DwButton`, `DwText`,
  `DwFlutterTheme`, `DwColorPreset`, `DwTextStylePreset`,
  `DwButtonStylePreset`, `DwDeviceFrame`, `MultiLinkText` and
  `context.isMobile` are gone. A design system is the one thing every app ends
  up owning; shipping it as a dependency only starts an argument about the
  corner radius of a button — and it forced an entire indirection apparatus
  (`ThemeExtension` + fallback presets) whose only job was to let framework
  widgets look up app styles. The UI kit now lives as source in the app's
  `lib/ui_kit/`, scaffolded by `dartway create` (see `example/`).
- **New: `DwActionBuilder`** — the mechanism that used to be trapped inside
  `DwButton`. It binds a `DwUiAction` to *any* tappable widget (a list tile, an
  icon, a card), holding the in-flight flag, blocking re-entrant taps and
  optionally validating the enclosing `Form`. The builder receives a ready
  `onPressed` (null while the action runs) and a `busy` flag.
  `DwUiAction` says *what* an action does; `DwActionBuilder` says what the UI
  does while it runs.
- **New: `DwPlugin`** — the seam for integrations the framework must not know
  about. Declared at startup (`DwCore(plugins: [...])`), initialized with the app
  core, and reached anywhere via `dw.plugin<T>()`. An integration package builds
  its own accessor on top, so the app writes `dw.telegram` — the ergonomics of an
  ambient service with none of the coupling, because the extension is declared in
  the integration package, not here.
- **Telegram moved out to `dartway_telegram`.** `DwConfig.telegramWebAppConfig`
  and `dw.services.telegramWebApp` are gone, and so is the `telegram_web_app`
  dependency. The framework's config has no business knowing a vendor's name,
  and an app that is not a Telegram Mini App should not download a Telegram SDK
  to get a bootstrap runner. `DwAppRunner` already declares itself
  "intentionally decoupled" — the Telegram field was the one place that wasn't.
- Dropped four dependencies: `adaptive_breakpoints` (**discontinued upstream**;
  it existed solely for `context.isMobile`, whose breakpoint was
  platform-dependent and surprising enough that app code bypassed it),
  `conditional_parent_widget` (unmaintained since 2023 and re-exported from the
  public barrel), `device_frame` and `telegram_web_app`. They now belong to the
  app's kit or to `dartway_telegram`, where they are the app's business. Six
  dependencies remain, down from ten.
- Feature declarations moved in from the Studio bridge: `DwFeature`,
  `DwFeatureSpec` and `scanMountedFeatures` are app semantics and now live
  here — feature catalogs, error-report context, analytics; a Studio binding
  maps them onto the bridge wire model.
- Error reporting pipeline: `dw.errorContext` (route source + custom lazy
  entries), `DwErrorReport`/`DwErrorSource`, `dw.handleError` captures an
  app-state snapshot (route, mounted features, action label, platform,
  version) and dispatches through the overridable `reportError`;
  `DwConfig.onErrorReport` and `DwConfig.appVersion` added. `DwAppRunner`
  routes uncaught zone errors into the pipeline by default.
- `DwUiAction.create`: new optional `label` (names the action in error
  reports; falls back to the notification texts) and `confirmation`
  (`DwUiConfirmation` + built-in `DwConfirmDialog`, customizable via
  `DwConfig.confirmDialogBuilder`) — declining skips the action entirely.
- Removed the legacy `zarchive` material-app wrapper and the unused
  `DwButtonNew` draft from the public surface.
