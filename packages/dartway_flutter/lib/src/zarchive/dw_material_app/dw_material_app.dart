// import 'package:dartway_flutter/dartway_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class DwMaterialApp extends ConsumerWidget {
//   const DwMaterialApp({
//     super.key,
//     required this.title,
//     required this.routerProvider,
//     required this.materialAppOptionsProvider,
//     this.appWrapper,
//   });

//   final ProviderBase<RouterConfig<Object>> routerProvider;
//   final ProviderBase<DwMaterialAppOptions> materialAppOptionsProvider;
//   final String title;
//   final Function(BuildContext context, Widget child)? appWrapper;
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final router = ref.watch(routerProvider);
//     final flutterAppOptions = ref.watch(materialAppOptionsProvider);

//     return MaterialApp.router(
//       routerConfig: router,
//       builder:
//           (context, child) => ConditionalParentWidget(
//             condition: appWrapper != null,
//             parentBuilder: (child) => appWrapper!(context, child),
//             child: DwNotificationsListener(
//               handlers: {DwUiNotification: DwUiNotificationHandler()},
//               child:
//                   flutterAppOptions.builder?.call(context, child) ??
//                   child ??
//                   SizedBox.shrink(),
//             ),
//           ),

//       debugShowCheckedModeBanner: flutterAppOptions.debugShowCheckedModeBanner,
//       title: title,
//       theme: flutterAppOptions.theme,
//       darkTheme: flutterAppOptions.darkTheme,
//       themeMode: flutterAppOptions.themeMode,
//       scrollBehavior: flutterAppOptions.scrollBehavior,
//       restorationScopeId: flutterAppOptions.restorationScopeId,
//       supportedLocales: Dw.instance.supportedLocales,
//       localizationsDelegates: flutterAppOptions.localizationDelegates,
//       localeResolutionCallback: flutterAppOptions.localeResolutionCallback,
//       localeListResolutionCallback:
//           flutterAppOptions.localeListResolutionCallback,
//     );
//   }
// }
