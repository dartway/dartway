part of '../dw_chat_ui_kit.dart';

class DwTypingDot extends HookWidget {
  final int delay;

  const DwTypingDot({
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final typingIndicatorSize =
        DwChatTheme.of(context).mainTheme.typingIndicatorSize;
    final typingIndicatorColor =
        DwChatTheme.of(context).mainTheme.typingIndicatorColor;
    final animation = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final animationValue = useAnimation<double>(
      Tween<double>(begin: 0.4, end: 1.0).animate(animation),
    );

    useEffect(() {
      Future.delayed(Duration(milliseconds: delay), () {
        animation.repeat(reverse: true);
      });
      return animation.dispose;
    }, [delay]);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animationValue,
          child: Container(
            width: typingIndicatorSize,
            height: typingIndicatorSize,
            decoration: BoxDecoration(
              color: typingIndicatorColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
