import 'dart:io';

/// Result of a single remote command.
class DwSshResult {
  const DwSshResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  /// First meaningful line of output, or of stderr when the command produced
  /// nothing on stdout.
  ///
  /// OpenSSH writes housekeeping notes to stderr — most often the one about
  /// adding a host to `known_hosts`. Reporting those as the reason a check
  /// failed sends the reader looking in the wrong place, so they are skipped.
  String get firstLine {
    final source = stdout.trim().isEmpty ? stderr : stdout;
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || _isSshNotice(trimmed)) {
        continue;
      }
      return trimmed;
    }
    return '';
  }

  static bool _isSshNotice(String line) =>
      line.startsWith('Warning: Permanently added') ||
      line.startsWith('Warning: the ECDSA host key') ||
      line.startsWith('Pseudo-terminal will not be allocated');
}

/// Runs commands on the deployment target over the system `ssh` client.
///
/// Shelling out rather than speaking SSH natively keeps the CLI free of a
/// crypto dependency and reuses the user's existing keys, agent and
/// `~/.ssh/config`. The OpenSSH client ships with macOS, Linux and Windows 10+.
class DwSshRunner {
  DwSshRunner({
    required this.host,
    required this.user,
    this.identityFile,
    this.connectTimeoutSeconds = 15,
  });

  final String host;
  final String user;
  final String? identityFile;
  final int connectTimeoutSeconds;

  String get target => '$user@$host';

  List<String> get _baseArgs => [
    // Never prompt: a check that blocks waiting for a passphrase is worse
    // than one that fails.
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'ConnectTimeout=$connectTimeoutSeconds',
    if (identityFile != null) ...[
      '-i',
      identityFile!,
      '-o',
      'IdentitiesOnly=yes',
    ],
    target,
  ];

  /// Runs [command] through the remote shell and captures its output.
  Future<DwSshResult> run(String command) async {
    try {
      final result = await Process.run('ssh', [..._baseArgs, command]);
      return DwSshResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (exception) {
      return DwSshResult(
        exitCode: 127,
        stdout: '',
        stderr: 'Cannot run ssh: ${exception.message}',
      );
    }
  }

  /// Wraps [command] so it runs as root: unchanged when the session already
  /// is root, through `sudo -n` when it is not.
  ///
  /// Cloud images are the reason this exists. Yandex Cloud, AWS and GCP all
  /// create an ordinary user with passwordless sudo and refuse a root login
  /// over SSH, so provisioning that insists on connecting as root cannot run
  /// on any of them — and the failure surfaces as `Permission denied` from
  /// `apt-get`, which names neither the cause nor the fix.
  ///
  /// `-n` keeps the promise the rest of this runner makes: nothing ever waits
  /// for a password. A user without passwordless sudo fails immediately and
  /// says so.
  static String privilegedCommand(String command) {
    final quoted = command.replaceAll("'", "'\\''");
    return "if [ \"\$(id -u)\" = 0 ]; then sh -c '$quoted'; "
        "else sudo -n sh -c '$quoted'; fi";
  }

  /// Runs [command] as root — see [privilegedCommand].
  Future<DwSshResult> runPrivileged(String command) =>
      run(privilegedCommand(command));

  /// Runs [command] as the deployment user via sudo, mirroring what the
  /// deployment itself does. Harmless when already connected as that user.
  Future<DwSshResult> runAs(String deployUser, String command) {
    return run(_asUser(deployUser, command));
  }

  /// Runs [command] as [deployUser] and feeds [input] to it on stdin.
  ///
  /// Secret values travel this way rather than as arguments: a command line is
  /// visible in `ps` to every user on the machine, stdin is not.
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) async {
    try {
      final process = await Process.start('ssh', [
        ..._baseArgs,
        _asUser(deployUser, command),
      ]);
      process.stdin.write(input);
      await process.stdin.flush();
      await process.stdin.close();

      final stdoutText = await process.stdout
          .transform(const SystemEncoding().decoder)
          .join();
      final stderrText = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      return DwSshResult(
        exitCode: await process.exitCode,
        stdout: stdoutText,
        stderr: stderrText,
      );
    } on ProcessException catch (exception) {
      return DwSshResult(
        exitCode: 127,
        stdout: '',
        stderr: 'Cannot run ssh: ${exception.message}',
      );
    }
  }

  /// Copies a local file to [remotePath] on the target.
  Future<DwSshResult> upload(String localPath, String remotePath) async {
    final args = [
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=accept-new',
      '-o',
      'ConnectTimeout=$connectTimeoutSeconds',
      if (identityFile != null) ...[
        '-i',
        identityFile!,
        '-o',
        'IdentitiesOnly=yes',
      ],
      localPath,
      '$target:$remotePath',
    ];
    try {
      final result = await Process.run('scp', args);
      return DwSshResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (exception) {
      return DwSshResult(
        exitCode: 127,
        stdout: '',
        stderr: 'Cannot run scp: ${exception.message}',
      );
    }
  }

  String _asUser(String deployUser, String command) {
    final quoted = command.replaceAll("'", "'\\''");
    return "if [ \"\$(id -un)\" = '$deployUser' ]; then sh -c '$quoted'; "
        "else sudo -u '$deployUser' -H sh -c '$quoted'; fi";
  }
}
