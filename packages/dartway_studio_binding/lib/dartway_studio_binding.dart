/// Binds a DartWay app to DartWay Studio.
///
/// One widget — [DwStudioBinding] — attaches the bridge, reports the route,
/// the features mounted on screen, the session and the language, and executes
/// what Studio asks for. Everything in it is mechanism the framework owns; a
/// project supplies only what is genuinely its own: the manifest, the screen
/// passports, and how to name the signed-in user.
///
/// The wire itself lives in `dartway_studio_bridge` — the contract both this
/// package and Studio depend on. When an app needs a report cadence of its own,
/// build the binding on `StudioBridgeHost.attach` directly, with the mapping
/// helpers exported here.
library;

export 'src/dw_studio_binding.dart';
export 'src/dw_studio_features.dart';
export 'src/dw_studio_locale.dart';
export 'src/dw_studio_route_spec.dart';
export 'src/dw_studio_user.dart';
