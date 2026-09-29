import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../data/dw_request_notifiers.dart';
import 'dw_read_states.dart';

/// The one way a screen shows a read: `dw.request`, `dw.table`, `dw.pages` or
/// `dw.window`, watched and rendered with every answer it can give.
///
/// ```dart
/// DwReadBuilder(
///   dw.request(GetCourse(courseId: id)),
///   placeholder: CourseCard.placeholder,
///   onRefused: {
///     DwCoreRefusal.notFound: (context, _) => const CourseUnavailable(),
///   },
///   builder: (context, course) => CourseCard(course),
/// )
/// ```
///
/// - **data** — [builder];
/// - **loading** — [builder] over [placeholder] as a skeleton, or the app's
///   `DwFlutterConfig.readLoadingBuilder` without one;
/// - **refused with a code [onRefused] names** — that branch: a screen of its
///   own for "not found", "closed", "not yours";
/// - **refused otherwise, failed, or out of reach** — the app's
///   `DwFlutterConfig.readFailedBuilder`, whose retry asks the same read
///   again (a refetch — never `ref.invalidate`, which reattaches to the same
///   failed state while the client still holds it); a failure is reported to
///   the error pipeline once;
/// - **signed out** — nothing: the session ended under a screen on its way
///   out, and the sign-in screen is the message.
///
/// Several reads on one screen nest: the inner builder sits in the outer
/// one's [builder].
///
/// **A value derived from reads** — a provider of the project's own in
/// `logic/` answering an `AsyncValue` — is rendered the same way with
/// [DwReadBuilder.derived], which takes the provider and says how to ask
/// again: `retry: (ref) => ref.read(dw.request(r).notifier).refetch()`. A
/// value the screen's chrome needs (a title, whether a button is enabled, a
/// badge) is not a builder's at all: it is a `logic/` provider answering a
/// plain value with a fallback, and a `DwReadBuilder` never stands in an app
/// bar. A widget does not take `.value`, `.when`, `.hasError` or
/// an `AsyncError` of a read itself — `dartway check` fails on it
/// (`forbiddenRequestRead`); a controller in `logic/` may watch a read to
/// derive its own state.
class DwReadBuilder<T> extends ConsumerWidget {
  /// A read of the data layer; its retry is the read's own `refetch()`.
  const DwReadBuilder(
    DwWatchProvider<T> this.read, {
    super.key,
    required this.builder,
    this.placeholder,
    this.onRefused = const {},
  }) : retry = null;

  /// A value derived from reads — any provider answering an `AsyncValue<T>`
  /// whose errors are the reads' (`DwRefusalException`, …) — with [retry],
  /// which asks the reads underneath again.
  const DwReadBuilder.derived(
    ProviderListenable<AsyncValue<T>> this.read, {
    super.key,
    required Future<void> Function(WidgetRef ref) this.retry,
    required this.builder,
    this.placeholder,
    this.onRefused = const {},
  });

  /// The read: `dw.request(…)`, `dw.table(…)`, `dw.pages(…)` or
  /// `dw.window(…)`; on [DwReadBuilder.derived], the provider deriving from
  /// reads.
  final ProviderListenable<AsyncValue<T>> read;

  /// How [DwReadBuilder.derived] asks again; `null` for a read of the data
  /// layer, which is refetched.
  final Future<void> Function(WidgetRef ref)? retry;

  /// The screen over the read's value.
  final Widget Function(BuildContext context, T value) builder;

  /// Stand-in data the loading skeleton is drawn from, through [builder].
  /// Without it the app's `readLoadingBuilder` shows — the right choice
  /// where drawing [builder] would itself read something.
  final T? placeholder;

  /// A branch per refusal code: `{DwCoreRefusal.notFound: (context, refusal)
  /// => …}`. A code not named here is the app's `readFailedBuilder`.
  final Map<DwRefusalCode, DwRefusedBuilder> onRefused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(read)) {
      case AsyncData(:final value):
        return builder(context, value);
      case AsyncError(:final error, :final stackTrace):
        return DwReadStates.failed(
          context,
          error,
          stackTrace,
          retry: () => switch (retry) {
            final retry? => retry(ref),
            _ => ref.read((read as DwWatchProvider<T>).notifier).refetch(),
          },
          onRefused: onRefused,
        );
      case AsyncLoading():
        final stand = placeholder;
        return DwReadStates.loading(
          context,
          placeholder: stand == null ? null : builder(context, stand),
        );
    }
  }
}
