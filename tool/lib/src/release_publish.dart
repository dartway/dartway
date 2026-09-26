/// Publishing a release plan, with pub.dev's `package-created` rate limit
/// (#313) as its own case rather than an ordinary failure.
///
/// A genuine failure still stops the whole run: the packages after it in the
/// order state carets on what did not go out, and nothing past that point can
/// be trusted. A rate limit is different — the short window clears on its
/// own, and the daily one blocks only the packages pub.dev has not seen
/// before, never an update to one it already knows. Stopping the world for
/// either wastes a release that could, for the most part, still go out.
library;

import 'pub_rate_limit.dart';
import 'release_order.dart';

/// One `dart pub publish` attempt's outcome, classified from its result —
/// exhaustive, so `publishRelease` cannot forget a case.
sealed class PublishAttempt {
  const PublishAttempt();
}

/// The package published.
class PublishOk extends PublishAttempt {
  const PublishOk();
}

/// pub.dev refused with its `package-created` rate limit.
class PublishRateLimited extends PublishAttempt {
  const PublishRateLimited(this.limit);
  final PackageCreatedRateLimit limit;
}

/// Anything else that made `dart pub publish` exit non-zero.
class PublishFailed extends PublishAttempt {
  const PublishFailed(this.output);

  /// The process's combined stdout and stderr, for the report.
  final String output;
}

/// Classifies one already-run `dart pub publish` attempt from its raw exit
/// code, stdout and stderr — pulled out of `release.dart`'s `_attemptPublish`
/// so the parsing is exercised by a test without shelling out to `dart pub
/// publish` for real (review of PR #358).
PublishAttempt classifyPublishResult({
  required int exitCode,
  required String stdout,
  required String stderr,
}) {
  if (exitCode == 0) return const PublishOk();
  final combined = '$stdout\n$stderr';
  final rateLimit = PackageCreatedRateLimit.parse(combined);
  if (rateLimit != null) return PublishRateLimited(rateLimit);
  return PublishFailed(combined);
}

/// What one run of [publishRelease] did.
class ReleasePublishReport {
  const ReleasePublishReport({
    required this.published,
    required this.deferred,
    this.stopped,
  });

  /// Package names published, in the order they went out.
  final List<String> published;

  /// Package name → why it was deferred: its own rate limit, or a
  /// dependency's.
  final Map<String, String> deferred;

  /// The package a genuine failure (not a rate limit) stopped the run at,
  /// and why — null when the run reached the end of the plan, whether or not
  /// anything was deferred along the way.
  final ({String name, String reason})? stopped;

  /// A release that is not everything the plan named: something was
  /// deferred, or a failure cut the run short. Either way this has to be
  /// visible as partial, per #313.
  bool get isPartial => deferred.isNotEmpty || stopped != null;
}

/// Publishes [plan] in order.
///
/// A package whose rate-limit answer names the short window is retried, up to
/// [maxShortWindowRetries] times, waiting [shortWindowRetryDelay] between
/// tries. A package whose answer names the long window is deferred instead —
/// along with every package later in [plan] that depends on it, directly or
/// transitively, found the same way `ReleaseOrder` finds anything: by walking
/// the plan in the order it is already in, so a dependency is always resolved
/// (deferred or not) before whatever depends on it is reached. Anything else
/// non-zero stops the run: [stopped] names where.
///
/// [attempt] makes exactly one `dart pub publish` try for a package and
/// classifies it. [confirmVisible] is the same visibility wait `release.dart`
/// always ran between two publishes that might depend on each other; it is
/// skipped after the last package actually attempted. [wait] is the
/// short-window backoff and [log] is where progress lines go — both injected
/// so a test using a fake [attempt] never really sleeps or writes to stdout.
Future<ReleasePublishReport> publishRelease(
  List<ReleaseUnit> plan, {
  required Future<PublishAttempt> Function(ReleaseUnit package) attempt,
  required Future<bool> Function(ReleaseUnit package) confirmVisible,
  required Future<void> Function(Duration) wait,
  required void Function(String) log,
  int maxShortWindowRetries = 5,
  Duration shortWindowRetryDelay = const Duration(minutes: 2),
}) async {
  final published = <String>[];
  final deferred = <String, String>{};

  for (var i = 0; i < plan.length; i++) {
    final package = plan[i];

    String? blockingDependency;
    for (final dependency in package.dependencies) {
      if (deferred.containsKey(dependency)) {
        blockingDependency = dependency;
        break;
      }
    }
    if (blockingDependency != null) {
      deferred[package.name] =
          'depends on $blockingDependency, itself deferred: '
          '${deferred[blockingDependency]}';
      log(
        '\n── ${i + 1}/${plan.length} ${package.name} — deferred: '
        '${deferred[package.name]}',
      );
      continue;
    }

    log('\n── ${i + 1}/${plan.length} ${package.name}');

    var tries = 0;
    PublishAttempt result;
    while (true) {
      tries++;
      result = await attempt(package);
      if (result is! PublishRateLimited) break;
      if (!result.limit.isShortWindow || tries > maxShortWindowRetries) break;
      log(
        '   pub.dev: package-created rate limit (${result.limit}). '
        'Waiting ${shortWindowRetryDelay.inMinutes}m to retry '
        '${package.name} ($tries/$maxShortWindowRetries)…',
      );
      await wait(shortWindowRetryDelay);
    }

    switch (result) {
      case PublishOk():
        published.add(package.name);
        if (i + 1 < plan.length && !await confirmVisible(package)) {
          return ReleasePublishReport(
            published: published,
            deferred: deferred,
            stopped: (
              name: package.name,
              reason:
                  'published, but pub.dev never listed it — stopping rather '
                  'than failing the next package on version solving',
            ),
          );
        }
      case PublishRateLimited(:final limit):
        deferred[package.name] = limit.isShortWindow
            ? 'still rate-limited after $maxShortWindowRetries retries '
                  '($limit)'
            : "pub.dev's daily package-created limit ($limit) — publish it "
                  'by hand once the window resets, or re-run this for the '
                  'rest of the order';
        log('   deferred: ${deferred[package.name]}');
      case PublishFailed(:final output):
        return ReleasePublishReport(
          published: published,
          deferred: deferred,
          stopped: (name: package.name, reason: output),
        );
    }
  }

  return ReleasePublishReport(published: published, deferred: deferred);
}
