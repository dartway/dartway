import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

class DwRoutingConfig {
  const DwRoutingConfig({
    this.goRouterOptionURLReflectsImperativeAPIs = true,
    this.removeHashSignFromUrl = true,
  });

  final bool? goRouterOptionURLReflectsImperativeAPIs;
  final bool removeHashSignFromUrl;

  init() {
    if (removeHashSignFromUrl == true) {
      usePathUrlStrategy();
    }

    if (goRouterOptionURLReflectsImperativeAPIs != null) {
      GoRouter.optionURLReflectsImperativeAPIs =
          goRouterOptionURLReflectsImperativeAPIs!;
    }
  }
}
