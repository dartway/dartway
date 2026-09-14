part of '../../ui_kit.dart';

/// "A new code in N s", counting down to the moment the server allows another
/// code, then the button that asks for one.
///
/// [availableAt] is the ticket's `resendAfter`: the server announces it, so the
/// countdown never offers a code the server would refuse as too early.
class ResendCodeButton extends HookWidget {
  const ResendCodeButton({
    required this.availableAt,
    required this.onResend,
    super.key,
  });

  final DateTime? availableAt;
  final DwUiAction<void> onResend;

  @override
  Widget build(BuildContext context) {
    int left() => switch (availableAt) {
      final moment? => max(
        0,
        (moment.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
      ),
      null => 0,
    };
    final seconds = useState(left());
    useEffect(() {
      seconds.value = left();
      if (seconds.value == 0) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        seconds.value = left();
        if (seconds.value == 0) timer.cancel();
      });
      return timer.cancel;
    }, [availableAt]);

    return Center(
      child: seconds.value > 0
          ? AppText.caption(context.l10n.resendCodeIn(seconds.value))
          : AppButton.text(context.l10n.resendCodeAction, onTap: onResend),
    );
  }
}
