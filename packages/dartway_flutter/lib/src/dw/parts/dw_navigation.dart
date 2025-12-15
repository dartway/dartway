part of '../dw.dart';

class _DwNavigation {
  _DwNavigation._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;
}
