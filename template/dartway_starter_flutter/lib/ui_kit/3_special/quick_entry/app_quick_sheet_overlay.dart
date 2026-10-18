part of '../../ui_kit.dart';

/// A fixed-height entry surface over a page, leaving navigation underneath.
///
/// Keep this mounted and change [isOpen] so dismissal can finish. Loading
/// content cannot change its reserved height. The surface extends beneath the
/// keyboard, while its content stops at the keyboard's top edge.
class AppQuickSheetOverlay extends HookWidget {
  const AppQuickSheetOverlay({
    required this.isOpen,
    required this.onDismiss,
    required this.dismissLabel,
    required this.child,
    this.onInputReady,
    super.key,
  });

  final bool isOpen;
  final VoidCallback onDismiss;
  final String dismissLabel;
  final Widget child;

  /// Called once per opening, 150 ms into the 250 ms entrance, leaving time
  /// for native keyboard startup. Web focus belongs in the opening gesture.
  final VoidCallback? onInputReady;

  static const openDuration = Duration(milliseconds: 250);
  static const closeDuration = Duration(milliseconds: 220);
  static const footerHeight = 16.0;

  static double navigationHeightOf(BuildContext context) =>
      kBottomNavigationBarHeight + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: openDuration,
      reverseDuration: closeDuration,
    );
    final latestInputReady = useRef(onInputReady)..value = onInputReady;
    final inputRequested = useRef(false);
    final lastGeometry = useRef<_QuickSheetGeometry?>(null);
    final leavingGeometry = useRef<_QuickSheetGeometry?>(null);
    useEffect(() {
      void inputReady() {
        if (controller.value >= 0.6 &&
            controller.status == AnimationStatus.forward &&
            !inputRequested.value) {
          inputRequested.value = true;
          latestInputReady.value?.call();
        }
      }

      controller.addListener(inputReady);
      return () => controller.removeListener(inputReady);
    }, [controller]);
    useEffect(() {
      if (isOpen) {
        inputRequested.value = false;
        leavingGeometry.value = null;
        controller.forward();
      } else if (!controller.isDismissed) {
        // Freeze the whole geometry, including the content height. Keyboard
        // dismissal must not resize a panel that is also sliding out.
        leavingGeometry.value = lastGeometry.value;
        FocusManager.instance.primaryFocus?.unfocus();
        controller.reverse();
      }
      return null;
    }, [isOpen]);

    return AppKeyboardInset(
      builder: (context, keyboard) {
        final bar = max(0.0, navigationHeightOf(context) - keyboard);
        final screen = MediaQuery.sizeOf(context).height;
        final geometry =
            leavingGeometry.value ??
            _QuickSheetGeometry(
              keyboard: keyboard,
              bar: bar,
              height: max(
                0.0,
                min(
                  screen * 0.7,
                  screen -
                      keyboard -
                      bar -
                      MediaQuery.paddingOf(context).top -
                      24,
                ),
              ),
            );
        lastGeometry.value = geometry;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.isDismissed) return const SizedBox.shrink();
            final progress = controller.status == AnimationStatus.reverse
                ? Curves.easeInCubic.transform(controller.value)
                : AppKeyboardInset.curve.transform(controller.value);
            final away = 1 - progress;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: geometry.bar,
                  child: Semantics(
                    button: true,
                    label: dismissLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDismiss,
                      child: Opacity(
                        opacity: Curves.easeOut.transform(controller.value),
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  bottom: geometry.bar,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, away * geometry.bar),
                      child: FractionalTranslation(
                        translation: Offset(0, away),
                        child: SizedBox(
                          height: geometry.height + geometry.keyboard,
                          width: double.infinity,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: geometry.keyboard,
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 4,
                                    ),
                                    child: SizedBox(
                                      width: 40,
                                      height: 4,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: child),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _QuickSheetGeometry {
  const _QuickSheetGeometry({
    required this.keyboard,
    required this.bar,
    required this.height,
  });
  final double keyboard;
  final double bar;
  final double height;
}
