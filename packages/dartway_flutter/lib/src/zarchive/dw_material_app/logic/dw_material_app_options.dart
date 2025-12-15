// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';

// class DwMaterialAppOptions {
//   final String title;
//   final ThemeData? theme;
//   final ThemeData? darkTheme;
//   final ThemeMode themeMode;
//   final List<Locale> supportedLocales;
//   final ScrollBehavior? scrollBehavior;
//   final String? restorationScopeId;
//   final bool debugShowCheckedModeBanner;

//   final LocaleResolutionCallback? localeResolutionCallback;
//   final LocaleListResolutionCallback? localeListResolutionCallback;
//   final List<LocalizationsDelegate<dynamic>> localizationDelegates;
//   final Widget Function(BuildContext, Widget?)? builder;

//   DwMaterialAppOptions({
//     required this.title,
//     this.theme,
//     this.darkTheme,
//     this.themeMode = ThemeMode.system,
//     required this.supportedLocales,
//     ScrollBehavior? scrollBehavior,
//     this.restorationScopeId,
//     this.debugShowCheckedModeBanner = false,
//     this.localeResolutionCallback,
//     this.localeListResolutionCallback,
//     this.localizationDelegates = const [
//       GlobalMaterialLocalizations.delegate,
//       GlobalWidgetsLocalizations.delegate,
//       GlobalCupertinoLocalizations.delegate,
//     ],
//     this.builder,
//   }) : scrollBehavior = scrollBehavior ?? defaultScrollBehavior;

//   static final defaultScrollBehavior = MaterialScrollBehavior().copyWith(
//     dragDevices: {...PointerDeviceKind.values},
//   );
// }
