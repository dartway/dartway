import '../network/dw_network_class.dart';

final class DwDownloadCandidate {
  DwDownloadCandidate({
    required this.candidateId,
    required this.packageId,
    required String host,
    required this.priority,
    required this.createdAtEpochMs,
  }) : host = host.toLowerCase() {
    if (candidateId.isEmpty || packageId.isEmpty || host.isEmpty) {
      throw ArgumentError('Download candidate identifiers must not be empty.');
    }
    if (priority < 0 || createdAtEpochMs < 0) {
      throw ArgumentError('Download candidate ordering values must be valid.');
    }
  }

  final String candidateId;
  final String packageId;
  final String host;
  final int priority;
  final int createdAtEpochMs;
}

abstract final class DwDownloadSchedulerPolicy {
  static const int maximumConcurrentPerHost = 2;

  static int maximumConcurrentDownloads(DwNetworkClass networkClass) {
    return switch (networkClass) {
      DwNetworkClass.offline => 0,
      DwNetworkClass.metered || DwNetworkClass.unknown => 1,
      DwNetworkClass.unmetered => 2,
    };
  }

  static List<DwDownloadCandidate> select({
    required DwNetworkClass networkClass,
    required Iterable<DwDownloadCandidate> activeDownloads,
    required Iterable<DwDownloadCandidate> candidates,
    int? maximumConcurrentOverride,
  }) {
    final active = activeDownloads.toList(growable: false);
    final maximumConcurrent =
        maximumConcurrentOverride ?? maximumConcurrentDownloads(networkClass);
    if (maximumConcurrent < 0) {
      throw ArgumentError.value(
        maximumConcurrent,
        'maximumConcurrentOverride',
        'must not be negative',
      );
    }
    var availableSlots = maximumConcurrent - active.length;
    if (availableSlots <= 0) return const [];

    final hostLoad = <String, int>{};
    final packageLoad = <String, int>{};
    for (final activeDownload in active) {
      hostLoad.update(
        activeDownload.host,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      packageLoad.update(
        activeDownload.packageId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final remaining = candidates.toList();
    final selected = <DwDownloadCandidate>[];
    while (availableSlots > 0 && remaining.isNotEmpty) {
      remaining.sort((left, right) {
        final loadComparison = (packageLoad[left.packageId] ?? 0).compareTo(
          packageLoad[right.packageId] ?? 0,
        );
        if (loadComparison != 0) return loadComparison;
        final priorityComparison = right.priority.compareTo(left.priority);
        if (priorityComparison != 0) return priorityComparison;
        final createdAtComparison = left.createdAtEpochMs.compareTo(
          right.createdAtEpochMs,
        );
        if (createdAtComparison != 0) return createdAtComparison;
        return left.candidateId.compareTo(right.candidateId);
      });
      final candidateIndex = remaining.indexWhere(
        (candidate) =>
            (hostLoad[candidate.host] ?? 0) < maximumConcurrentPerHost,
      );
      if (candidateIndex == -1) break;
      final candidate = remaining.removeAt(candidateIndex);
      selected.add(candidate);
      hostLoad.update(candidate.host, (count) => count + 1, ifAbsent: () => 1);
      packageLoad.update(
        candidate.packageId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      availableSlots--;
    }
    return List.unmodifiable(selected);
  }
}
