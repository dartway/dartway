part of '../dw_chat_ui_kit.dart';

class DwBubbleOverlay extends HookWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;
  final Future<void> Function() onDelete;
  final VoidCallback onEdit;
  final void Function(String emoji) onReact;
  final bool isCustomMessage;

  const DwBubbleOverlay({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
    required this.onDelete,
    required this.onEdit,
    required this.onReact,
    required this.isCustomMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);
    final overlayEntry = useState<OverlayEntry?>(null);
    final tapPosition = useState<Offset?>(null);
    final overlayLeft = useState<double?>(null);
    final overlayTop = useState<double?>(null);
    final overlayKey = useMemoized(() => GlobalKey());

    final textColor = Theme.of(context).iconTheme.color;

    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 250),
    );

    void showOverlay() {
      if (overlayEntry.value != null) return;

      final overlay = Overlay.of(context);
      final screenSize = MediaQuery.of(context).size;
      final tap = tapPosition.value ??
          Offset(screenSize.width / 2, screenSize.height / 2);

      const overlayMaxWidth = 260.0;

      // начальные (грубые) координаты до измерения
      double left = tap.dx - overlayMaxWidth / 2;
      double top = tap.dy - 100; // предположим среднюю высоту до измерения

      left = left.clamp(8, screenSize.width - overlayMaxWidth - 8);
      top = top.clamp(32, screenSize.height - 100 - 16);

      final entry = OverlayEntry(
        builder: (context) => FadeTransition(
          opacity: animationController,
          child: Stack(
            children: [
              // затемнение
              GestureDetector(
                onTap: () {
                  animationController.reverse().then((_) {
                    overlayEntry.value?.remove();
                    overlayEntry.value = null;
                    overlayLeft.value = null;
                    overlayTop.value = null;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                    color: Colors.black.withOpacity(0.7),
                    width: double.infinity,
                    height: double.infinity),
              ),
              // сам блок
              Positioned(
                left: overlayLeft.value ?? left,
                top: overlayTop.value ?? top,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animationController, curve: Curves.easeOutBack),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      key: overlayKey,
                      // убрали height, даём контенту задавать размер
                      constraints:
                          const BoxConstraints(maxWidth: overlayMaxWidth),
                      decoration: BoxDecoration(
                        color:
                            theme.mainTheme.backgroundColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AnimatedListTile(
                            leading: Icon(Icons.reply, color: textColor),
                            title: Text('Ответить',
                                style: TextStyle(color: textColor)),
                            onTap: () {
                              onReply();
                              animationController.reverse().then((_) {
                                overlayEntry.value?.remove();
                                overlayEntry.value = null;
                              });
                            },
                          ),
                          if (isMe) ...[
                            if (!isCustomMessage)
                              _AnimatedListTile(
                                leading: Icon(Icons.edit, color: textColor),
                                title: Text('Редактировать',
                                    style: TextStyle(color: textColor)),
                                onTap: () {
                                  onEdit();
                                  animationController.reverse().then((_) {
                                    overlayEntry.value?.remove();
                                    overlayEntry.value = null;
                                  });
                                },
                              ),
                            _AnimatedListTile(
                              leading: Icon(Icons.delete,
                                  color: theme.mainTheme.errorColor),
                              title: Text('Удалить',
                                  style: TextStyle(
                                      color: theme.mainTheme.errorColor)),
                              onTap: () async {
                                await animationController.reverse().then((_) {
                                  overlayEntry.value?.remove();
                                  overlayEntry.value = null;
                                });
                                await onDelete();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      overlay.insert(entry);
      overlayEntry.value = entry;
      animationController.forward();

      // дождёмся построения и измерим размер
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = overlayKey.currentContext?.size;
        if (size == null) return;

        final newLeft = (tap.dx - size.width / 2)
            .clamp(8.0, screenSize.width - size.width - 8.0);
        final newTop = (tap.dy - size.height)
            .clamp(32.0, screenSize.height - size.height - 16.0);

        overlayLeft.value = newLeft;
        overlayTop.value = newTop;
        overlayEntry.value?.markNeedsBuild();
      });
    }

    return GestureDetector(
      onTapDown: (details) {
        tapPosition.value = details.globalPosition;
      },
      onLongPress: () {
        showOverlay();
      },
      child: child,
    );
  }
}

// Виджет с анимацией нажатия для IconButton
class _AnimatedIconButton extends HookWidget {
  final VoidCallback onPressed;
  final Widget icon;

  const _AnimatedIconButton({
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 150),
    );

    return GestureDetector(
      onTapDown: (_) {
        animationController.forward();
      },
      onTapUp: (_) {
        animationController.reverse();
        onPressed();
      },
      onTapCancel: () {
        animationController.reverse();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.2).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: icon,
      ),
    );
  }
}

// Виджет с анимацией нажатия для ListTile
class _AnimatedListTile extends HookWidget {
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  const _AnimatedListTile({
    required this.leading,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 150),
    );

    return GestureDetector(
      onTapDown: (_) {
        animationController.forward();
      },
      onTapUp: (_) {
        animationController.reverse();
        onTap();
      },
      onTapCancel: () {
        animationController.reverse();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: ListTile(
          leading: leading,
          title: title,
        ),
      ),
    );
  }
}
