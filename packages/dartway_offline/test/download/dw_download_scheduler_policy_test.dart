import 'package:dartway_offline/src/download/dw_download_scheduler_policy.dart';
import 'package:dartway_offline/src/network/dw_network_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDownloadSchedulerPolicy', () {
    test('network class controls global concurrency', () {
      expect(
        DwDownloadSchedulerPolicy.maximumConcurrentDownloads(
          DwNetworkClass.offline,
        ),
        0,
      );
      expect(
        DwDownloadSchedulerPolicy.maximumConcurrentDownloads(
          DwNetworkClass.unmetered,
        ),
        2,
      );
      expect(
        DwDownloadSchedulerPolicy.maximumConcurrentDownloads(
          DwNetworkClass.metered,
        ),
        1,
      );
      expect(
        DwDownloadSchedulerPolicy.maximumConcurrentDownloads(
          DwNetworkClass.unknown,
        ),
        1,
      );
    });

    test('unmetered selection gives the first pass to different packages', () {
      final selected = DwDownloadSchedulerPolicy.select(
        networkClass: DwNetworkClass.unmetered,
        activeDownloads: const [],
        candidates: [
          candidate('a-1', packageId: 'a', priority: 5, createdAt: 1),
          candidate('a-2', packageId: 'a', priority: 5, createdAt: 2),
          candidate('b-1', packageId: 'b', priority: 1, createdAt: 3),
        ],
      );

      expect(selected.map((item) => item.candidateId), ['a-1', 'b-1']);
    });

    test('one package can use all otherwise idle slots', () {
      final selected = DwDownloadSchedulerPolicy.select(
        networkClass: DwNetworkClass.unmetered,
        activeDownloads: const [],
        candidates: [
          candidate('a-2', packageId: 'a', priority: 1, createdAt: 2),
          candidate('a-1', packageId: 'a', priority: 1, createdAt: 1),
        ],
      );

      expect(selected.map((item) => item.candidateId), ['a-1', 'a-2']);
    });

    test('active package yields the next slot to an idle package', () {
      final selected = DwDownloadSchedulerPolicy.select(
        networkClass: DwNetworkClass.unmetered,
        activeDownloads: [
          candidate('a-active', packageId: 'a', priority: 10, createdAt: 0),
        ],
        candidates: [
          candidate('a-next', packageId: 'a', priority: 10, createdAt: 1),
          candidate('b-next', packageId: 'b', priority: 1, createdAt: 2),
        ],
      );

      expect(selected.map((item) => item.candidateId), ['b-next']);
    });

    test('host cap excludes candidates when two host tasks are active', () {
      final selected = DwDownloadSchedulerPolicy.select(
        networkClass: DwNetworkClass.unmetered,
        maximumConcurrentOverride: 3,
        activeDownloads: [
          candidate('active-1', packageId: 'a', host: 'files.example'),
          candidate('active-2', packageId: 'b', host: 'files.example'),
        ],
        candidates: [
          candidate('blocked', packageId: 'c', host: 'files.example'),
          candidate('allowed', packageId: 'd', host: 'cdn.example'),
        ],
      );

      expect(selected.map((item) => item.candidateId), ['allowed']);
    });

    test('priority then FIFO determines order inside a fairness level', () {
      final selected = DwDownloadSchedulerPolicy.select(
        networkClass: DwNetworkClass.unmetered,
        activeDownloads: const [],
        candidates: [
          candidate('low', packageId: 'a', priority: 1, createdAt: 1),
          candidate('new', packageId: 'b', priority: 5, createdAt: 2),
          candidate('old', packageId: 'c', priority: 5, createdAt: 1),
        ],
      );

      expect(selected.map((item) => item.candidateId), ['old', 'new']);
    });
  });
}

DwDownloadCandidate candidate(
  String candidateId, {
  required String packageId,
  String host = 'files.example',
  int priority = 0,
  int createdAt = 0,
}) {
  return DwDownloadCandidate(
    candidateId: candidateId,
    packageId: packageId,
    host: host,
    priority: priority,
    createdAtEpochMs: createdAt,
  );
}
