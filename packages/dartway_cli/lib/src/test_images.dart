import 'dart:io';

/// How many times [dwEnsureImage] asks the registry before giving up.
const _attempts = 3;

Duration _defaultBackoff(int attempt) =>
    attempt == 1 ? const Duration(seconds: 2) : const Duration(seconds: 5);

/// Makes sure [image] is present locally before a container is started from
/// it, and answers null when it is, or the reason when it could not be.
///
/// The pull is separate from `docker run` so that it can be retried: a
/// registry answering a timeout, a 5xx or a rate limit is transient, and
/// leaving the pull to `run` turned one such answer into a failed test run.
/// `run` itself is not retried — a failed `run` can leave a created container
/// behind, and a retry there cannot tell a pull error from a start error.
///
/// An image already present asks nothing of the network. Otherwise
/// `docker pull` is tried up to three times, waiting [backoff] after attempt
/// `n` before the next one (2 s, then 5 s); one line per attempt goes to
/// stderr, and the pull's own progress output does not.
Future<String?> dwEnsureImage(
  String image, {
  required Future<ProcessResult?> Function(List<String>) docker,
  Duration Function(int attempt) backoff = _defaultBackoff,
}) async {
  final inspect = await docker([
    'image',
    'inspect',
    '--format',
    '{{.Id}}',
    image,
  ]);
  if (inspect == null) return 'could not pull $image: Docker is not available';
  if (inspect.exitCode == 0) return null;

  var reason = '';
  for (var attempt = 1; attempt <= _attempts; attempt++) {
    if (attempt > 1) await Future<void>.delayed(backoff(attempt - 1));
    stderr.writeln('pulling $image (attempt $attempt/$_attempts)');
    final pull = await docker(['pull', image]);
    if (pull == null) return 'could not pull $image: Docker is not available';
    if (pull.exitCode == 0) return null;
    reason = _lastLine('${pull.stderr}') ?? reason;
  }
  return 'could not pull $image after $_attempts attempts: $reason';
}

String? _lastLine(String output) {
  final lines = output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  return lines.isEmpty ? null : lines.last;
}
