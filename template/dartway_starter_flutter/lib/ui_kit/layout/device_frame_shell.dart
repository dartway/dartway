part of '../ui_kit.dart';

/// Desktop shell for a mobile-first app: on a wide screen the app is rendered
/// inside a phone frame flanked by optional side panels; on mobile it is shown
/// as-is.
class DeviceFrameShell extends StatelessWidget {
  const DeviceFrameShell({
    required this.body,
    super.key,
    this.customWrapCondition,
    this.leftSidePanel = const SizedBox.shrink(),
    this.leftSidePanelFlex = 1,
    this.rightSidePanel = const SizedBox.shrink(),
    this.rightSidePanelFlex = 1,
  });

  final Widget body;
  final bool Function(BuildContext context)? customWrapCondition;
  final Widget leftSidePanel;
  final int leftSidePanelFlex;
  final Widget rightSidePanel;
  final int rightSidePanelFlex;

  @override
  Widget build(BuildContext context) {
    return ConditionalParent(
      // Its own threshold, not `!context.isMobile`: framing a phone needs room
      // for the phone *and* the desk it sits on.
      condition:
          customWrapCondition?.call(context) ??
          MediaQuery.sizeOf(context).width >=
              AppBreakpoints.deviceFrameMinWidth,
      parentBuilder: (child) => Scaffold(
        body: Row(
          children: [
            Expanded(flex: leftSidePanelFlex, child: leftSidePanel),
            Padding(
              padding: const EdgeInsets.all(24),
              child: DeviceFrame(
                device: Devices.ios.iPhone13ProMax,
                isFrameVisible: true,
                orientation: Orientation.portrait,
                screen: SafeArea(child: child),
              ),
            ),
            Expanded(flex: rightSidePanelFlex, child: rightSidePanel),
          ],
        ),
      ),
      child: body,
    );
  }
}
