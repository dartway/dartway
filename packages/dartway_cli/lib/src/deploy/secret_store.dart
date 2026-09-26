import 'dart:io';

import 'package:path/path.dart' as p;

import 'deploy_target.dart';
import 'ssh_runner.dart';
import 'stack.dart';

/// The runtime secret store on a deployment target.
///
/// One file of `KEY='value'` lines in the runtime configuration directory —
/// outside Git and outside the checkout, so the `git reset --hard` a deploy
/// performs can never touch it. The format is the one Compose reads an
/// environment file in, single-quoted so that a value is taken literally: no
/// `$` interpolation, no `#` comment, no escape. Every deploy renders the
/// checkout's `.env` from it after checking it, which is what the server is
/// started with.
///
/// Values reach the store over stdin and are never passed as arguments, which
/// would put them in the remote process list; and nothing here ever prints
/// one. Where a question can be answered by key names — is it there, is it
/// empty — only names travel.
class DwSecretStore {
  DwSecretStore({required this.ssh, required this.target, String? directory})
    : directory = directory ?? target.runtimeConfigDir;

  final DwSshRunner ssh;
  final DwDeployTarget target;

  /// Where the store lives. The target's runtime directory unless a caller —
  /// the local proof — keeps it somewhere else.
  final String directory;

  static const String fileName = 'secrets.env';

  String get file => '$directory/$fileName';

  Future<DwSshResult> _run(String script) =>
      ssh.runAs(target.deployUser, script);

  /// Encodes one line of the store, or explains why [value] cannot be one.
  ///
  /// A single-quoted value cannot hold a single quote — the format has no
  /// escape — and cannot span lines. Both are refused rather than mangled: a
  /// secret that does not survive the trip is worse than a missing one, since
  /// the server starts and fails somewhere far from here.
  static String encodeLine(String key, String value) {
    if (!dwIsSecretKeyName(key)) {
      throw DwSecretFormatException(
        '"$key" is not a secret name: upper case letters, digits and '
        'underscores, not starting with a digit or with COMPOSE_.',
      );
    }
    if (value.contains("'")) {
      throw DwSecretFormatException(
        'The value of $key contains a single quote. The store keeps values '
        'single-quoted so that nothing in them is interpreted, and that form '
        'has no escape for the quote itself.',
      );
    }
    if (value.contains('\n') || value.contains('\r')) {
      throw DwSecretFormatException(
        'The value of $key spans lines. Store a document with '
        '"dartway deploy secret put-file" instead.',
      );
    }
    return "$key='$value'";
  }

  /// The pattern of a well-formed line, as a POSIX extended regex.
  static const String linePattern = "^[A-Z_][A-Z0-9_]*='[^']*'\$";

  /// Parses store text into keys and values. Blank lines and `#` comments are
  /// skipped; anything else that is not a well-formed line is an error naming
  /// its line number and never its content.
  static Map<String, String> parse(String text) {
    final values = <String, String>{};
    final line = RegExp(r"^([A-Z_][A-Z0-9_]*)='([^']*)'$");
    final lines = text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final raw = lines[index].trimRight();
      if (raw.isEmpty || raw.startsWith('#')) continue;
      final match = line.firstMatch(raw);
      if (match == null) {
        throw DwSecretFormatException(
          'line ${index + 1} of the store is not KEY=\'value\'',
        );
      }
      if (values.containsKey(match.group(1))) {
        throw DwSecretFormatException(
          '${match.group(1)} is declared twice in the store',
        );
      }
      values[match.group(1)!] = match.group(2)!;
    }
    return values;
  }

  /// The directories between the deploy user's home and [directory], which
  /// the user has to be able to write for the store to be created — nearest
  /// the home first.
  ///
  /// Empty when [directory] is not under that home: a store kept elsewhere
  /// (the local proof) is its caller's business.
  static List<String> directoriesToOwn({
    required String home,
    required String directory,
  }) {
    final path = p.posix;
    if (!path.isWithin(home, directory)) return const [];
    final chain = <String>[];
    for (var d = path.dirname(directory); d != home; d = path.dirname(d)) {
      chain.insert(0, d);
    }
    return chain;
  }

  /// Creates the store directory if absent. Idempotent.
  ///
  /// A directory on the way that the deploy user cannot write — in practice
  /// `~/.config` left behind by an earlier tool that ran as root — is taken
  /// back first, non-recursively. Without that, `install -d` reports
  /// "cannot change permissions … No such file or directory", which names
  /// neither the directory nor its owner. Only a directory inside the user's
  /// own home is ever changed; if it cannot be, the failure says which one,
  /// whose it is, and the command that fixes it.
  Future<DwSshResult> ensureDirectory() async {
    final chain = directoriesToOwn(
      home: '/home/${target.deployUser}',
      directory: directory,
    );
    final notes = <String>[];
    if (chain.isNotEmpty) {
      final list = chain.map((d) => "'$d'").join(' ');
      final blocked = await _run(
        'for d in $list; do '
        '[ -e "\$d" ] && [ ! -w "\$d" ] && echo "\$d \$(stat -c %U "\$d")"; '
        'done; true',
      );
      for (final line in blocked.stdout.split('\n')) {
        final parts = line.trim().split(' ');
        if (parts.length != 2) continue;
        final (dir, owner) = (parts[0], parts[1]);
        final user = target.deployUser;
        final taken = await ssh.runPrivileged("chown '$user:$user' '$dir'");
        if (!taken.ok) {
          return DwSshResult(
            exitCode: taken.exitCode,
            stdout: '',
            stderr:
                '$dir belongs to $owner, so $user cannot create the secret '
                "store inside it; as root: chown '$user:$user' '$dir'",
          );
        }
        notes.add('took $dir back from $owner');
      }
    }
    final created = await _run("install -d -m 0700 '$directory'");
    if (notes.isEmpty || !created.ok) return created;
    return DwSshResult(
      exitCode: created.exitCode,
      stdout: [...notes, created.stdout].where((l) => l.isNotEmpty).join('\n'),
      stderr: created.stderr,
    );
  }

  /// Key names in the store. Values never leave the server.
  Future<DwSecretKeyNames> readKeyNames() =>
      _names("s/^\\([A-Z_][A-Z0-9_]*\\)=.*/\\1/p");

  /// Names of keys whose value is not empty.
  ///
  /// Emptiness is not a secret, so asking for it costs nothing — and it is the
  /// difference between "this environment has a mail key" and "this
  /// environment has a placeholder where the mail key goes".
  Future<DwSecretKeyNames> readNonEmptyKeyNames() =>
      _names("s/^\\([A-Z_][A-Z0-9_]*\\)='[^']\\{1,\\}'\$/\\1/p");

  Future<DwSecretKeyNames> _names(String sedProgram) async {
    final result = await _run(
      "test -f '$file' && sed -n \"$sedProgram\" '$file'",
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

  /// Generates every key of [keys] that the store does not already hold, as
  /// that many random bytes in hex. Existing values are never replaced —
  /// regenerating the database password would lock the server out of a
  /// database initialised with the old one.
  ///
  /// Prints the names it generated, one per line, and nothing else.
  Future<DwSshResult> generateMissing(Map<String, int> keys) {
    for (final key in keys.keys) {
      encodeLine(key, '');
    }
    final pairs = keys.entries.map((e) => '${e.key}:${e.value}').join(' ');
    return _run('''
set -e
umask 077
file='$file'
[ -e "\$file" ] || : > "\$file"
for pair in $pairs; do
  key=\${pair%%:*}
  bytes=\${pair#*:}
  if grep -q "^\$key=" "\$file"; then
    continue
  fi
  value=\$(openssl rand -hex "\$bytes")
  # A generator that printed nothing would store an empty password and report
  # success; the length is the proof it ran.
  [ \${#value} -eq \$((bytes * 2)) ] || { echo "openssl produced no value for \$key" >&2; exit 1; }
  printf "%s='%s'\\n" "\$key" "\$value" >> "\$file"
  echo "\$key"
done
chmod 600 "\$file"
''');
  }

  /// Writes [key], replacing any existing value.
  ///
  /// The encoded line travels on stdin, so the value appears in neither the
  /// SSH command line nor the remote process list. It is staged in a
  /// `mktemp` file inside [directory] itself — never the shared system temp
  /// directory — and that staging file is removed on any failure. The store
  /// is rewritten through a second temporary copy, in the same directory,
  /// moved into place so a reader never sees it half-written and the swap is
  /// one same-filesystem rename, not a copy a crash could catch half-done.
  Future<DwSshResult> setSecret({required String key, required String value}) {
    final line = encodeLine(key, value);
    return ssh.runAsWithInput(target.deployUser, '''
set -e
umask 077
install -d -m 0700 '$directory'
file='$file'
line_file=\$(mktemp '$directory/.secrets-line.XXXXXX')
trap 'rm -f "\$line_file"' EXIT
cat > "\$line_file"
[ -e "\$file" ] || : > "\$file"
# grep answers 1 when it keeps no line at all, which is not a failure here;
# 2 is, and must not leave a store holding nothing but the new key.
{ grep -v "^$key=" "\$file" || [ \$? -eq 1 ]; } > "\$file.tmp"
cat "\$line_file" >> "\$file.tmp"
mv "\$file.tmp" "\$file"
chmod 600 "\$file"
''', '$line\n');
  }

  /// Replaces the whole store with [values]. Used by `secret push`.
  ///
  /// [expectedFingerprint], when given, must equal the store's current
  /// `cksum` (`'absent'` for no store) right before anything is written; a
  /// mismatch — the store changed since it was read — writes nothing and
  /// fails instead. This is [DwSecretPushPlan.fingerprint], and it is what
  /// closes the gap between planning a push and sending it: two calls, not
  /// one transaction, and a second push (or a hand edit) landing in between
  /// would otherwise be silently undone by a decision made against what the
  /// store used to hold. Omitted, this writes unconditionally, as it always
  /// did — callers other than `secret push` that replace the store outright
  /// have no earlier read to hold it to.
  ///
  /// The plaintext is staged in a `mktemp` file inside [directory] itself —
  /// never in the shared, world-writable system temp directory — removed on
  /// any failure before it is moved into place, and moved rather than copied
  /// into [file] so the swap is one rename on one filesystem, never a
  /// cross-filesystem copy a crash could catch half-done.
  Future<DwSshResult> writeAll(
    Map<String, String> values, {
    String? expectedFingerprint,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Written by "dartway deploy secret push".')
      ..writeln(
        '# The master copy lives in deploy/secrets.yaml on the '
        "maintainer's machine.",
      );
    for (final entry in values.entries) {
      buffer.writeln(encodeLine(entry.key, entry.value));
    }
    final guard = expectedFingerprint == null
        ? ''
        : '''
if [ -f '$file' ]; then
  current=\$(cksum < '$file')
else
  current='absent'
fi
if [ "\$current" != '$expectedFingerprint' ]; then
  echo 'the store changed since it was last read; nothing was written' >&2
  exit 1
fi
''';
    return ssh.runAsWithInput(target.deployUser, '''
set -e
umask 077
install -d -m 0700 '$directory'
$guard
staged=\$(mktemp '$directory/.secrets.XXXXXX')
trap 'rm -f "\$staged"' EXIT
cat > "\$staged"
test -s "\$staged"
mv "\$staged" '$file'
chmod 600 '$file'
''', buffer.toString());
  }

  /// Compares [candidate] to what the store already holds, key by key,
  /// without moving a value off the server: the comparison itself runs
  /// there, over the candidate's own encoded lines sent on stdin (read
  /// directly, never staged in a file of their own), and only three sets of
  /// names — plus every key name currently in the store, and a fingerprint
  /// of it — come back.
  ///
  /// What `secret push` plans its default from: [DwSecretPushPlan.add] is
  /// what the server lacks or holds empty, [DwSecretPushPlan.same] already
  /// matches, and [DwSecretPushPlan.differ] is what a caller must decide
  /// about (`--overwrite`) rather than have replaced silently.
  /// [DwSecretPushPlan.names] is what a caller computes `--prune`'s orphaned
  /// keys from, in the same pass as the fingerprint: a separate call to list
  /// them (as `secret push` once made) reads the store a second time, and a
  /// key added to it in the gap between the two calls would be missed by
  /// that guard.
  /// [DwSecretPushPlan.ok] is false, and nothing is classified, when the
  /// store exists but could not be read (permissions, most likely) — an
  /// unreadable store must never be mistaken for an absent one, which would
  /// class every key `add` and let a push replace it outright.
  Future<DwSecretPushPlan> plan(Map<String, String> candidate) async {
    final buffer = StringBuffer();
    for (final entry in candidate.entries) {
      buffer.writeln(encodeLine(entry.key, entry.value));
    }
    final result = await ssh.runAsWithInput(target.deployUser, '''
set -e
if [ -f '$file' ]; then
  # Read (and fingerprinted, and its key names listed) before anything is
  # classified against it: a read failure discovered midway through the
  # loop below would otherwise leave whatever it had already printed on
  # stdout looking like a complete, successful plan, and grep failing on
  # one key for the same reason would look exactly like that key simply not
  # being in the store.
  fingerprint=\$(cksum < '$file')
else
  fingerprint='absent'
fi
echo "FINGERPRINT \$fingerprint"
if [ -f '$file' ]; then
  sed -n "s/^\\([A-Z_][A-Z0-9_]*\\)=.*/NAME \\1/p" '$file'
fi
while IFS= read -r line || [ -n "\$line" ]; do
  key=\${line%%=*}
  [ -n "\$key" ] || continue
  if [ -f '$file' ]; then
    # grep answers 1 for "no such line", which is not a failure here; 2 is,
    # and must not be read as the key simply being absent.
    existing=\$(grep "^\$key=" '$file' || [ \$? -eq 1 ])
  else
    existing=''
  fi
  case "\$existing" in
    '' | "\$key=''") echo "ADD \$key" ;;
    "\$line") echo "SAME \$key" ;;
    *) echo "DIFFER \$key" ;;
  esac
done
''', buffer.toString());

    if (!result.ok) {
      return DwSecretPushPlan(
        ok: false,
        add: const {},
        same: const {},
        differ: const {},
        names: const {},
        fingerprint: '',
        error: result.firstLine,
      );
    }
    final add = <String>{};
    final same = <String>{};
    final differ = <String>{};
    final names = <String>{};
    var fingerprint = '';
    for (final raw in result.stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final space = line.indexOf(' ');
      if (space < 0) continue;
      final tag = line.substring(0, space);
      final rest = line.substring(space + 1);
      switch (tag) {
        case 'ADD':
          add.add(rest);
        case 'SAME':
          same.add(rest);
        case 'DIFFER':
          differ.add(rest);
        case 'NAME':
          names.add(rest);
        case 'FINGERPRINT':
          fingerprint = rest;
      }
    }
    return DwSecretPushPlan(
      ok: true,
      add: add,
      same: same,
      differ: differ,
      names: names,
      fingerprint: fingerprint,
      error: '',
    );
  }

  /// Reads the whole store. Only `pull` uses this: routine checks compare key
  /// names, which never requires moving a value.
  Future<DwSshResult> readFile() => _run("cat '$file'");

  /// Renders the environment file the stack is started with, into [appDir].
  ///
  /// On the server, so no value makes a round trip through this machine. It
  /// refuses — naming keys and line numbers, never values — when the store is
  /// absent, holds a line Compose would read differently from what was meant,
  /// declares a key twice, holds a name the compose file sets itself (which
  /// would be silently overridden), or lacks a non-empty value for any of
  /// [required]. A server started without its secrets fails later and far
  /// from here; this is the last point where the reason is still obvious.
  ///
  /// Prints one line: how many keys it rendered.
  Future<DwSshResult> renderEnvironment({
    required String appDir,
    required List<String> required,
    required Set<String> reserved,
  }) => _run(
    renderEnvironmentScript(
      appDir: appDir,
      required: required,
      reserved: reserved,
    ),
  );

  /// The script [renderEnvironment] runs, for a caller that runs it its own
  /// way — a deployment step detached from the connection.
  String renderEnvironmentScript({
    required String appDir,
    required List<String> required,
    required Set<String> reserved,
  }) {
    final requiredList = required.join(' ');
    final reservedList = (reserved.toList()..sort()).join(' ');
    return '''
set -e
umask 077
store='$file'
out='$appDir/${DwStack.envFile}'
if [ ! -s "\$store" ]; then
  echo "ERROR: no secret store at \$store. Run: dartway deploy secret init --env ${target.environment}" >&2
  exit 1
fi
bad=\$(grep -nvE "$linePattern|^#|^[[:space:]]*\$" "\$store" | cut -d: -f1 | tr '\\n' ' ' || true)
if [ -n "\$bad" ]; then
  echo "ERROR: line(s) \$bad of \$store are not KEY='value'. Rewrite them with: dartway deploy secret set" >&2
  exit 1
fi
dupes=\$(sed -n "s/^\\([A-Z_][A-Z0-9_]*\\)=.*/\\1/p" "\$store" | sort | uniq -d | tr '\\n' ' ')
if [ -n "\$dupes" ]; then
  echo "ERROR: declared more than once in \$store: \$dupes" >&2
  exit 1
fi
clash=""
for key in $reservedList; do
  if grep -q "^\$key=" "\$store"; then clash="\$clash \$key"; fi
done
if [ -n "\$clash" ]; then
  echo "ERROR: the store holds\$clash, which the compose file sets itself and would silently override. Remove them from the store." >&2
  exit 1
fi
missing=""
for key in $requiredList; do
  if ! grep -qE "^\$key='[^']+'\\\$" "\$store"; then missing="\$missing \$key"; fi
done
if [ -n "\$missing" ]; then
  echo "ERROR: missing or empty in \$store:\$missing. Generated keys come from: dartway deploy secret init --env ${target.environment}; the rest from: dartway deploy secret set <KEY> --env ${target.environment}" >&2
  exit 1
fi
staged=\$(mktemp "$appDir/.env.XXXXXX")
{
  echo '# Rendered by "dartway deploy" from the secret store. Do not edit: the next deploy replaces it.'
  grep -E "$linePattern" "\$store"
} > "\$staged"
chmod 600 "\$staged"
mv "\$staged" "\$out"
echo "rendered \$(grep -cE "$linePattern" "\$out") key(s) into \$out"
''';
  }

  /// Uploads a secret file (service account JSON and similar) into the store.
  Future<DwSshResult> putFile(File local, {required String name}) async {
    if (!dwIsSecretFileName(name)) {
      throw DwSecretFormatException(
        '"$name" cannot be a stored file name: letters, digits, dots, dashes '
        'and underscores, and not ${DwSecretStore.fileName}.',
      );
    }
    final staging = '/tmp/dw-secret-${DateTime.now().microsecondsSinceEpoch}';
    final uploaded = await ssh.upload(local.path, staging);
    if (!uploaded.ok) {
      return uploaded;
    }
    return ssh.run(
      DwSshRunner.privilegedCommand(
        "install -d -m 0700 -o '${target.deployUser}' -g '${target.deployUser}' "
        "'$directory' && "
        "install -m 0600 -o '${target.deployUser}' -g '${target.deployUser}' "
        "'$staging' '$directory/$name' && rm -f '$staging'",
      ),
    );
  }

  /// Names of the files present in the store, the key file excluded.
  Future<DwSecretFileNames> listFiles() async {
    final result = await _run("test -d '$directory' && ls -1A '$directory'");
    return DwSecretFileNames(
      ok: result.ok,
      names: result.stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && line != fileName)
          .toList(),
    );
  }
}

/// A value or a name the store cannot hold as given.
class DwSecretFormatException implements Exception {
  DwSecretFormatException(this.message);

  final String message;

  @override
  String toString() => message;
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

/// The result of [DwSecretStore.plan]: every candidate key sorted into what
/// pushing it would do, by name only — never a value, from either side.
class DwSecretPushPlan {
  const DwSecretPushPlan({
    required this.ok,
    required this.add,
    required this.same,
    required this.differ,
    required this.names,
    required this.fingerprint,
    required this.error,
  });

  final bool ok;

  /// The server lacks the key, or holds it empty.
  final Set<String> add;

  /// The server already holds exactly this value.
  final Set<String> same;

  /// The server holds a different, non-empty value.
  final Set<String> differ;

  /// Every key name the store held at the moment this plan read it — read in
  /// the same pass as [fingerprint], not a separate call: a push computes
  /// `--prune`'s orphaned keys (the server's names minus the candidate's) by
  /// diffing against this set, rather than by asking the store to list its
  /// keys a second time, which would read it again and could miss a key
  /// added in the gap between the two reads. Empty when there was no store
  /// yet, or when [ok] is false.
  final Set<String> names;

  /// A fingerprint (`cksum`) of the store exactly as it was when this plan
  /// read it — `'absent'` when there was no store yet. Meant for
  /// [DwSecretStore.writeAll]'s `expectedFingerprint`: passed back there, it
  /// refuses to write over a store that no longer matches it, closing the
  /// gap between planning a push and sending it. Empty when [ok] is false.
  final String fingerprint;

  final String error;
}

/// File names in the store directory.
class DwSecretFileNames {
  const DwSecretFileNames({required this.ok, required this.names});

  /// False when the directory could not be listed — which is not the same
  /// answer as an empty one.
  final bool ok;
  final List<String> names;
}
