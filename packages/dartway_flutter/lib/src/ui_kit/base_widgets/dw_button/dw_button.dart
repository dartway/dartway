import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

import 'private/dw_default_button_types.dart';

class DwButton extends StatelessWidget {
  final Widget? _body;
  final String? _label;
  final DwDefaultButtonType? _type;
  final DwButtonStylePreset? _style;
  final DwUiAction<dynamic>? dwCallback;
  final Widget? leading;
  final Widget? trailing;
  final bool showProgress;
  final double? width;
  final double? height;
  final bool unfocusOnTap;
  final bool requireValidation;

  const DwButton(
    Widget body, {
    required DwButtonStylePreset stylePreset,
    required this.dwCallback,
    super.key,
    this.leading,
    this.trailing,
    this.showProgress = true,
    this.width,
    this.height,
    this.unfocusOnTap = true,
    this.requireValidation = false,
  })  : _label = null,
        _body = body,
        _style = stylePreset,
        _type = null;

  const DwButton.primary(
    String label, {
    required this.dwCallback,
    this.leading,
    this.trailing,
    super.key,
    this.showProgress = true,
    this.width,
    this.height,
    this.unfocusOnTap = true,
    this.requireValidation = false,
  })  : _label = label,
        _body = null,
        _type = DwDefaultButtonType.primary,
        _style = null;

  const DwButton.secondary(
    String label, {
    required this.dwCallback,
    this.leading,
    this.trailing,
    super.key,
    this.showProgress = true,
    this.width,
    this.height,
    this.unfocusOnTap = true,
    this.requireValidation = false,
  })  : _label = label,
        _body = null,
        _type = DwDefaultButtonType.secondary,
        _style = null;

  const DwButton.text(
    String label, {
    required this.dwCallback,
    this.leading,
    this.trailing,
    super.key,
    this.showProgress = true,
    this.width,
    this.height,
    this.unfocusOnTap = true,
    this.requireValidation = false,
  })  : _label = label,
        _body = null,
        _type = DwDefaultButtonType.text,
        _style = null;

  @override
  Widget build(BuildContext context) {
    return
        // SizedBox(
        //   width: width,
        //   height: height,
        //   child:
        _DwGuardedButton(
      style: (_style ?? _type!.resolvePreset(context)).resolveStyle(context),
      onPressed: dwCallback == null
          ? null
          : () {
              if (unfocusOnTap) {
                FocusScope.of(context).unfocus();
              }

              if (!requireValidation ||
                  (Form.maybeOf(context)?.validate() ?? false)) {
                dwCallback!.call(context);
              }
            },
      showProgress: showProgress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          _body ?? Text(_label ?? ''),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
      // ),
    );
  }
}

class _DwGuardedButton extends StatefulWidget {
  final Widget child;
  final ButtonStyle style;
  final FutureOr<void> Function()? onPressed;
  final bool showProgress;

  const _DwGuardedButton({
    required this.child,
    required this.style,
    this.onPressed,
    this.showProgress = false,
  });

  @override
  State<_DwGuardedButton> createState() => _GuardedButtonState();
}

class _GuardedButtonState extends State<_DwGuardedButton> {
  bool _busy = false;

  Future<void> _handle() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSpinner = widget.showProgress && _busy;

    return ElevatedButton(
      style: widget.style,
      onPressed: widget.onPressed != null ? _handle : null,
      child: showSpinner
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.child,
    );
  }
}
