// part 'dw_router_state.g.dart';

// @riverpod
// class DwRouterState extends _$DwRouterState {
//   @override
//   GoRouter build(DwRouterConfig config) {
//     final redirects = config.redirectsProvider != null
//         ? ref.watch(config.redirectsProvider!)
//         : null;

//     // Create a config with redirects applied
//     final configWithRedirects = config.withRedirects(redirects);

//     return configWithRedirects.build();
//   }
// }

// ProviderFamily<GoRouter, DwRouterConfig> dwRouterStateProvider(
//     DwRouterConfig config) {
//   return Provider.family<GoRouter, DwRouterConfig>(
//     (ref, cfg) {
//       final redirects = cfg.redirectsProvider != null
//           ? ref.watch(cfg.redirectsProvider!)
//           : null;

//       final configWithRedirects = cfg.withRedirects(redirects);
//       return configWithRedirects.build();
//     },
//     // 👇 ключевая строчка — теперь router зависит от redirectsProvider
//     dependencies: config.redirectsProvider != null
//         ? [config.redirectsProvider!]
//         : const [],
//   );
// }
