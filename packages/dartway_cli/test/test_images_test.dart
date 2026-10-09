import 'dart:io';

import 'package:dartway_cli/src/test_images.dart';
import 'package:test/test.dart';

const _image = 'postgres:17-alpine';

/// A `docker` that answers `image inspect` with [present] and each `pull`
/// with the next exit code of [pulls], recording every call it receives.
class _FakeDocker {
  _FakeDocker({required this.present, this.pulls = const []});

  final bool? present;
  final List<int> pulls;
  final calls = <List<String>>[];

  int get pullCount => calls.where((call) => call.first == 'pull').length;

  Future<ProcessResult?> call(List<String> arguments) async {
    calls.add(arguments);
    if (arguments.first == 'image') {
      if (present == null) return null;
      return present!
          ? ProcessResult(0, 0, 'sha256:abc\n', '')
          : ProcessResult(0, 1, '', 'Error: No such image: $_image\n');
    }
    final exitCode = pulls[pullCount - 1];
    return exitCode == 0
        ? ProcessResult(0, 0, 'Status: Downloaded newer image\n', '')
        : ProcessResult(
            0,
            exitCode,
            '',
            'Error response from daemon: Head "https://registry-1.docker.io/'
                'v2/library/postgres/manifests/17-alpine": '
                'toomanyrequests: attempt $pullCount\n\n',
          );
  }
}

Future<String?> _ensure(_FakeDocker docker) =>
    dwEnsureImage(_image, docker: docker.call, backoff: (_) => Duration.zero);

void main() {
  test('an image already present is not pulled', () async {
    final docker = _FakeDocker(present: true);

    expect(await _ensure(docker), isNull);
    expect(docker.calls, [
      ['image', 'inspect', '--format', '{{.Id}}', _image],
    ]);
  });

  test(
    'a pull that fails twice and then succeeds is retried to success',
    () async {
      final docker = _FakeDocker(present: false, pulls: [1, 1, 0]);

      expect(await _ensure(docker), isNull);
      expect(docker.pullCount, 3);
      expect(docker.calls.last, ['pull', _image]);
    },
  );

  test('three failed pulls name the image and the last error line', () async {
    final docker = _FakeDocker(present: false, pulls: [1, 1, 1]);

    expect(
      await _ensure(docker),
      'could not pull $_image after 3 attempts: Error response from daemon: '
      'Head "https://registry-1.docker.io/v2/library/postgres/manifests/'
      '17-alpine": toomanyrequests: attempt 3',
    );
    expect(docker.pullCount, 3);
  });

  test('without Docker nothing is pulled and the reason says so', () async {
    final docker = _FakeDocker(present: null);

    expect(
      await _ensure(docker),
      'could not pull $_image: Docker is not available',
    );
    expect(docker.pullCount, 0);
  });

  test('waits between attempts and not after the last', () async {
    final waits = <int>[];
    final docker = _FakeDocker(present: false, pulls: [1, 1, 1]);

    await dwEnsureImage(
      _image,
      docker: docker.call,
      backoff: (attempt) {
        waits.add(attempt);
        return Duration.zero;
      },
    );
    expect(waits, [1, 2]);
  });
}
