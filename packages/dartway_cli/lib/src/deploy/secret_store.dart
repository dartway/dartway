import 'dart:io';

import 'deploy_target.dart';
import 'ssh_runner.dart';

/// The runtime secret store on a deployment target.
///
/// Secrets live outside Git and outside the repository checkout, so that the
/// `git reset --hard` a deploy performs can never touch them.
///
/// A server holds only its own slice: `shared` plus its run mode section,
/// which is exactly what Serverpod merges at startup. Where the authoritative
/// copy lives is the project's choice — the local `passwords.yaml` covering
/// every environment, or the servers themselves. Either way values reach the
/// store over stdin and are never passed as arguments, which would put them in
/// the remote process list.
class DwSecretStore {
  DwSecretStore({required this.ssh, required this.target});

  final DwSshRunner ssh;
  final DwDeployTarget target;

  String get directory => target.runtimeConfigDir;

  String get passwordsFile => '$directory/passwords.yaml';

  /// Keys Serverpod and DartWay read at startup. Generating them needs no
  /// human input — they are random strings, not credentials issued elsewhere.
  static const generatedKeys = [
    'database',
    'serviceSecret',
    'dwAuthKeySalt',
    'dwVerificationCodeSalt',
  ];

  Future<DwSshResult> _run(String script) =>
      ssh.runAs(target.deployUser, script);

  /// Creates the store directory if absent. Idempotent.
  Future<DwSshResult> ensureDirectory() =>
      _run("install -d -m 0700 '$directory'");

  /// Key names declared under any of [sections]. Values never leave the server.
  Future<DwSecretKeyNames> readKeyNames({
    required List<String> sections,
  }) async {
    final pattern = sections.map(RegExp.escape).join('|');
    final program = [
      r'/^[^[:space:]#]/ { inside = ($0 ~ ("^(" wanted "):[[:space:]]*$")) }',
      r'inside && /^[[:space:]]+[A-Za-z]/ {',
      r'  key = $0; sub(/:.*/, "", key); gsub(/^[[:space:]]+/, "", key);',
      r'  print key',
      r'}',
    ].join(' ');
    final result = await _run(
      "test -s '$passwordsFile' && "
      "awk -v wanted='$pattern' '$program' '$passwordsFile'",
    );
    return DwSecretKeyNames(
      ok: result.ok,
      names: result.stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet(),
      error: result.firstLine,
    );
  }

  /// Names of keys under [sections] whose value is not empty.
  ///
  /// Emptiness is not a secret, so asking for it costs nothing — and it is the
  /// difference between "this environment has a mail key" and "this
  /// environment has a placeholder where the mail key goes".
  Future<DwSecretKeyNames> readNonEmptyKeyNames({
    required List<String> sections,
  }) async {
    final pattern = sections.map(RegExp.escape).join('|');
    final program = [
      r'/^[^[:space:]#]/ { inside = ($0 ~ ("^(" wanted "):[[:space:]]*$")) }',
      r'inside && /^[[:space:]]+[A-Za-z]/ {',
      r'  key = $0; sub(/:.*/, "", key); gsub(/^[[:space:]]+/, "", key);',
      r'  value = $0; sub(/^[[:space:]]*[A-Za-z0-9_]+:[[:space:]]*/, "", value);',
      r'  sub(/[[:space:]]+$/, "", value);',
      r'  if (value != "" && value != "\x27\x27" && value != "\"\"") print key',
      r'}',
    ].join(' ');
    final result = await _run(
      "test -s '$passwordsFile' && "
      "awk -v wanted='$pattern' '$program' '$passwordsFile'",
    );
    return DwSecretKeyNames(
      ok: result.ok,
      names: result.stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet(),
      error: result.firstLine,
    );
  }

  /// Generates every key of [keys] that is not already present under
  /// [section]. Existing values are never replaced — regenerating
  /// `dwAuthKeySalt` would invalidate every issued auth key.
  Future<DwSshResult> generateMissing({
    required String section,
    required List<String> keys,
  }) {
    final list = keys.join(' ');
    return _run('''
set -e
umask 077
file='$passwordsFile'
[ -e "\$file" ] || : > "\$file"
grep -q '^$section:' "\$file" || printf '%s:\\n' '$section' >> "\$file"
for key in $list; do
  if awk -v s='$section' '
      /^[^[:space:]#]/ { inside = (\$0 ~ ("^" s ":[[:space:]]*\$")) }
      inside && \$0 ~ ("^[[:space:]]+" k ":") { found = 1 }
      END { exit found ? 0 : 1 }
    ' k="\$key" "\$file"; then
    continue
  fi
  value=\$(openssl rand -hex 32)
  awk -v s='$section' -v line="  \$key: \$value" '
    { print }
    \$0 ~ ("^" s ":[[:space:]]*\$") { print line }
  ' "\$file" > "\$file.tmp"
  mv "\$file.tmp" "\$file"
done
chmod 600 "\$file"
''');
  }

  /// Encodes [value] as a YAML single-quoted scalar.
  ///
  /// Single quoting has exactly one escape — a quote is doubled — so the
  /// encoding is done here rather than on the server. Nothing downstream has
  /// to parse or re-escape anything.
  static String encodeScalar(String value) =>
      "'${value.replaceAll("'", "''")}'";

  /// Writes [key] under [section], replacing any existing value.
  ///
  /// The already-encoded line travels on stdin, so the value appears in
  /// neither the SSH command line nor the remote process list, and the remote
  /// side never has to escape anything. The file is rewritten through a
  /// temporary copy and moved into place, so a reader never sees it
  /// half-written.
  Future<DwSshResult> setSecret({
    required String section,
    required String key,
    required String value,
  }) {
    if (value.contains('\n')) {
      throw StateError('A secret value must be a single line.');
    }
    final line = '  $key: ${encodeScalar(value)}';
    return ssh.runAsWithInput(target.deployUser, '''
set -e
umask 077
file='$passwordsFile'
line_file=\$(mktemp)
cat > "\$line_file"
[ -e "\$file" ] || : > "\$file"
grep -q '^$section:' "\$file" || printf '%s:\\n' '$section' >> "\$file"
awk -v s='$section' -v k='$key' -v line_file="\$line_file" '
  /^[^[:space:]#]/ { inside = (\$0 ~ ("^" s ":[[:space:]]*\$")) }
  inside && \$0 ~ ("^[[:space:]]+" k ":") { next }
  { print }
  \$0 ~ ("^" s ":[[:space:]]*\$") {
    while ((getline injected < line_file) > 0) print injected
  }
' "\$file" > "\$file.tmp"
mv "\$file.tmp" "\$file"
rm -f "\$line_file"
chmod 600 "\$file"
''', line);
  }

  /// Replaces the whole store file with [sections].
  ///
  /// Used to push a slice of the local master file to the server it belongs
  /// to. Values are re-encoded as quoted strings, which is what Serverpod's
  /// password loader requires — it rejects a section holding anything but
  /// strings.
  Future<DwSshResult> writeSections(Map<String, Map<String, String>> sections) {
    final buffer = StringBuffer()
      ..writeln('# Written by "dartway deploy secret push".')
      ..writeln('# The master copy lives on the maintainer machine.')
      ..writeln();
    for (final section in sections.entries) {
      buffer.writeln('${section.key}:');
      for (final entry in section.value.entries) {
        buffer.writeln('  ${entry.key}: ${encodeScalar(entry.value)}');
      }
      buffer.writeln();
    }

    return ssh.runAsWithInput(target.deployUser, '''
set -e
umask 077
file='$passwordsFile'
staged=\$(mktemp)
cat > "\$staged"
test -s "\$staged"
install -d -m 0700 '$directory'
mv "\$staged" "\$file"
chmod 600 "\$file"
''', buffer.toString());
  }

  /// Reads the whole store file.
  ///
  /// Parsing happens locally rather than on the server: the value of a secret
  /// can hold anything, and shell-quoting it correctly on the far side is how
  /// this kind of code goes wrong. Only `pull` uses this — routine checks
  /// compare key names, which never requires moving a value.
  Future<DwSshResult> readFile() => _run("cat '$passwordsFile'");

  /// Uploads a secret file (service account JSON and similar) into the store.
  Future<DwSshResult> putFile(File local, {required String name}) async {
    final staging = '/tmp/dw-secret-${DateTime.now().microsecondsSinceEpoch}';
    final uploaded = await ssh.upload(local.path, staging);
    if (!uploaded.ok) {
      return uploaded;
    }
    return ssh.run(
      "install -d -m 0700 -o '${target.deployUser}' -g '${target.deployUser}' "
      "'$directory' && "
      "install -m 0600 -o '${target.deployUser}' -g '${target.deployUser}' "
      "'$staging' '$directory/$name' && rm -f '$staging'",
    );
  }

  /// Names of the files present in the store.
  Future<List<String>> listFiles() async {
    final result = await _run("ls -1 '$directory' 2>/dev/null || true");
    return result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

/// Key names read from the store, without values.
class DwSecretKeyNames {
  const DwSecretKeyNames({
    required this.ok,
    required this.names,
    required this.error,
  });

  final bool ok;
  final Set<String> names;
  final String error;
}
