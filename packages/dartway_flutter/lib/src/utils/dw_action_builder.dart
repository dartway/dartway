import 'package:flutter/material.dart';

import 'dw_ui_action.dart';

/// Builds a widget that runs a [DwUiAction], given the guarded press handler
/// and the in-flight flag.
///
/// [onPressed] is `null` while the action runs (and when there is no action),
/// so the built widget renders itself disabled for free.
typedef DwActionWidgetBuilder =
    Widget Function(BuildContext context, VoidCallback? onPressed, bool busy);

/// Binds a [DwUiAction] to any tappable widget.
///
/// [DwUiAction] describes *what* an action does — confirmation, notifications,
/// follow-up, error reporting. It does not track whether it is currently
/// running. This widget adds exactly that missing piece: it holds the in-flight
/// state, blocks re-entrant taps, optionally validates the enclosing [Form],
/// and hands the builder a ready-to-use `onPressed` plus a `busy` flag.
///
/// The framework deliberately ships no button of its own: the app owns how its
/// controls look, and any widget — a button, a list tile, an icon, a card — can
/// be made action-safe here.
///
/// ```dart
/// DwActionBuilder(
///   action: deleteAction,
///   builder: (context, onPressed, busy) => ListTile(
///     onTap: onPressed,
///     trailing: busy
///         ? const CircularProgressIndicator()
///         : const Icon(Icons.delete),
///   ),
/// )
/// ```
class DwActionBuilder extends StatefulWidget {
  const DwActionBuilder({
    required this.action,
    required this.builder,
    super.key,
    this.requireValidation = false,
    this.unfocusOnTap = true,
  });

  /// The action to run. When `null`, the builder receives a `null` `onPressed`.
  final DwUiAction<dynamic>? action;

  /// Builds the tappable widget from the guarded handler and the in-flight flag.
  final DwActionWidgetBuilder builder;

  /// Validates the enclosing [Form] before running; cancels when it fails.
  ///
  /// With no enclosing [Form] there is nothing to validate and the action runs
  /// — asserting in debug, because a `requireValidation` that finds no form is
  /// almost always a mistake, and a button that silently does nothing is the
  /// worst way to learn about it.
  final bool requireValidation;

  /// Drops keyboard focus before the action runs.
  final bool unfocusOnTap;

  @override
  State<DwActionBuilder> createState() => _DwActionBuilderState();
}

class _DwActionBuilderState extends State<DwActionBuilder> {
  bool _busy = false;

  Future<void> _run() async {
    final action = widget.action;
    if (_busy || action == null) return;

    if (widget.unfocusOnTap) {
      FocusScope.of(context).unfocus();
    }

    // No enclosing form means nothing to validate, so the action runs. The
    // opposite (`?? false`) is what a guard must never do: it would swallow
    // every tap in silence and leave the developer staring at a dead button.
    // The mistake itself is caught in build, before the first tap.
    if (widget.requireValidation &&
        !(Form.maybeOf(context)?.validate() ?? true)) {
      return;
    }

    setState(() => _busy = true);
    try {
      await action(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Complain where the mistake was made, not on the first tap that quietly
    // does nothing. This guard used to live inside `DwButton`, always within
    // the form its author had in mind; it now sits under any tappable widget,
    // so drifting out of the `Form` is easy — and a validation with nothing to
    // validate is not a thing anyone means to write.
    assert(
      !widget.requireValidation || Form.maybeOf(context) != null,
      'DwActionBuilder(requireValidation: true) found no enclosing Form. '
      'Wrap it in one, or drop requireValidation.',
    );

    return widget.builder(
      context,
      widget.action == null || _busy ? null : _run,
      _busy,
    );
  }
}
