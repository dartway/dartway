import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// What a section shows when its read did not answer — a sentence and a way out
/// of it.
///
/// `dwBuildAsync`/`dwBuildListAsync` default `errorWidget` to
/// `SizedBox.shrink()`, which is correct for a decoration and wrong for the
/// section its screen exists for: an empty page already means "nothing has been
/// created yet", and a failed read means "go and look at the backend". Only the
/// caller can tell the two apart, so the caller passes `errorBuilder:` — see
/// `dartway-clean-code` §1.5a.
///
/// The framework ships no widget of this kind on purpose: the copy is
/// user-visible and has to come from `context.l10n`, which a package cannot
/// own.
///
/// [onRetry] is the one callback that earns its place (`dartway-clean-code`
/// §1.9b): only the caller knows which read failed, and a `DwUiAction` is a
/// value the framework means to be passed around. It is built at the call site
/// as `dw.action((_) => ref.invalidate(theProvider))` — the sanctioned use of
/// `invalidate` (§1.5), because the reset and the flicker are exactly what the
/// person pressing "retry" asked for.
class LoadFailedMessage extends StatelessWidget {
  const LoadFailedMessage({required this.onRetry, super.key});

  /// Throws the failed read away and asks again.
  final DwUiAction<void> onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.body(context.l10n.loadFailed, textAlign: TextAlign.center),
        AppButton.text(context.l10n.retry, onTap: onRetry),
      ],
    ),
  );
}
