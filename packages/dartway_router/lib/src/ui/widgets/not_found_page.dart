import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dartway_router/src/core/navigation_zones/navigation_zone_route.dart';

class NotFoundPageWidget extends StatefulWidget {
  const NotFoundPageWidget({
    super.key,
    required this.redirectRoute,
    this.infoWidget = const Text('Page not found'),
    this.showCounter = true,
    this.showRedirectButton = true,
  });

  final Widget infoWidget;
  final NavigationZoneRoute redirectRoute;
  final bool showCounter;
  final bool showRedirectButton;

  @override
  State<NotFoundPageWidget> createState() => _NotFoundPageWidgetState();
}

class _NotFoundPageWidgetState extends State<NotFoundPageWidget> {
  Timer? _timer;
  int _counter = -1;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter == -1) {
        setState(() {
          _counter = 3;
        });
      } else if (_counter > 0) {
        setState(() {
          _counter--;
        });
      } else if (_counter == 0) {
        timer.cancel();
        if (mounted) {
          context.goNamed(widget.redirectRoute.name);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.infoWidget,
            if (widget.showCounter && _counter != -1) Text('$_counter'),
            if (widget.showRedirectButton)
              IconButton(
                onPressed: () {
                  context.goNamed(widget.redirectRoute.name);
                },
                icon: const Icon(Icons.reply),
              ),
          ],
        ),
      ),
    );
  }
}
