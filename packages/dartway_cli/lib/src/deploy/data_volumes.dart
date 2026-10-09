// ignore_for_file: unused_import
import 'package:path/path.dart' as p;

import 'deploy_target.dart';
import 'secret_store.dart';
import 'stack.dart';

/// One data-volume guard, judged the same way whether it runs from `deploy
/// setup` or `deploy run` — the reason it lives here instead of inline in
/// either command. The stack-identity guard ([judgeStackIdentity]) answers
/// in the same shape.
///
/// Pass or fail, generic: it reads volume names, never a storage's own. A
/// config change that renames a service, moves it to a different backend, or
/// drops one it used to declare is caught the same way — by what is missing
/// on the server, not by what changed in `deploy/config.yaml`.
class DwDataVolumeVerdict {
  const DwDataVolumeVerdict.pass(this.detail) : ok = true;
  const DwDataVolumeVerdict.fail(this.detail) : ok = false;

  final bool ok;

  /// What was found, stated on success too — the report doubles as a
  /// description of what is on the server.
  final String detail;
}

/// Judges whether starting a stack that expects [expectedDataVolumes] (every
/// name already carrying the compose project's prefix, e.g.
/// `shop_postgres_data` — see [DwStack.dataVolumeNames]) would create one of
/// them empty beside a data volume of the same project that already holds
/// real state.
///
/// [volumeListing] is the raw output of `docker volume ls --format
/// '{{.Name}}'` on the server; [projectPrefix] is [DwDeployTarget.projectName]
/// — the checkout directory's name, which is what Compose derives every
/// volume name from (`<projectPrefix>_<name>`, never the bucket prefix a
/// project's own S3 rules use, which is the server package's name and can
/// differ from the checkout's).
///
/// The judgement rests on two sets: [expectedDataVolumes] not found on the
/// server (**missing**) and data volumes found on the server that the current
/// configuration does not expect at all (**strangers**). Only *both at once*
/// mean something: a stranger with nothing missing is the rollback copy of a
/// change already completed; something missing with no stranger beside it is
/// either a first deploy or a part of the stack turned on for the first time
/// (`storage: bundled` where a project never had storage before) — either
/// way, nothing existing names the volume that would be created, so nothing
/// is at risk of being silently discarded. Certbot's own volume is excluded
/// from both sets: a certificate lineage reissues itself, so it is not "data"
/// in the sense this guard protects, and counting it would refuse a
/// project's first `storage: bundled` for no better reason than TLS having
/// run before it.
///
/// **Fails** exactly when a missing expected volume and a stranger coexist —
/// the shape of any config change that renames a data-bearing service on a
/// server that already ran the old name: the rendered stack would start the
/// newly expected volume empty, its own init step would write its probes
/// into nothing, the outside checks would read those probes and pass, and
/// every real object would 404 from then on, silently. (The change that
/// motivated this guard, dartway/dartway#331/D-094, is the framework's own
/// data point — read there for the concrete example — not something this
/// code knows by name.)
DwDataVolumeVerdict judgeDataVolumes({
  required String volumeListing,
  required String projectPrefix,
  required Set<String> expectedDataVolumes,
}) {
  final existingData = volumeListing
      .split('\n')
      .map((line) => line.trim())
      .where(
        (line) =>
            line.startsWith('${projectPrefix}_') &&
            line.endsWith('_data') &&
            !line.contains('certbot'),
      )
      .toSet();

  final missing = expectedDataVolumes.difference(existingData);
  final strangers = existingData.difference(expectedDataVolumes);

  if (missing.isEmpty) {
    final sorted = expectedDataVolumes.toList()..sort();
    return DwDataVolumeVerdict.pass('${sorted.join(', ')} already present');
  }

  if (strangers.isEmpty) {
    return existingData.isEmpty
        ? const DwDataVolumeVerdict.pass(
            'no existing data volume for this project — a first deploy',
          )
        : DwDataVolumeVerdict.pass(
            '${(existingData.toList()..sort()).join(', ')} already present; '
            '${(missing.toList()..sort()).join(', ')} would be created new — '
            'nothing existing names it, so there is nothing it could start '
            'empty beside',
          );
  }

  final strangersSorted = strangers.toList()..sort();
  final missingSorted = missing.toList()..sort();
  return DwDataVolumeVerdict.fail(
    'this server already has ${strangersSorted.join(', ')}, and the rendered '
    'configuration would start ${missingSorted.join(', ')} empty beside it — '
    'a config change (a rename, a different storage backend) is about to '
    'serve fresh data next to the real one, and nothing downstream would '
    'notice: the new volume gets its own probe objects, the outside checks '
    'read those and pass, and every real file 404s from then on.\n'
    'Bring the expected volume up with the real data on it first — copy it '
    'from wherever it lives now, verify the copy, then run this again. Once '
    '${missingSorted.length == 1 ? 'it exists' : 'they exist'}, this passes '
    'regardless of what else is still on the server: an old volume from '
    'before the change is the rollback copy, and nothing here asks for it '
    'to be removed.',
  );
}

/// What [judgeStackIdentity] reads from the server, as the deployment user:
/// the Docker volumes, then every secret store under `~/.config` — names
/// only, never contents. A server with neither prints nothing, which is a
/// fresh server, not a failure.
///
/// The two listings come back as one: a volume name never holds a `/`, and
/// every store path does, so [judgeStackIdentity] tells them apart by that.
String dwStackIdentityScript(DwDeployTarget target) {
  final configRoot = p.posix.dirname(target.runtimeConfigDir);
  return "set -e\n"
      "docker volume ls --format '{{.Name}}'\n"
      "ls -1 '$configRoot'/*/${DwSecretStore.fileName} 2>/dev/null || true";
}

/// Judges whether the server [dwStackIdentityScript] listed runs this
/// project's stack, before anything is written or started there.
///
/// [projectName] is the whole identity of a deployment on its server
/// ([DwDeployTarget.projectName]): the checkout, the secret store, the
/// Compose project and every data volume hang off it. It falls back to the
/// repository's name, so a repository that moves renames the deployment —
/// and every guard keyed by that name, [judgeDataVolumes] among them, sees an
/// empty server beside the live stack and lets a second one start there.
/// This guard looks at every stack instead.
///
/// A stack is named by a data volume of a known kind
/// (`<name>_${DwStack.postgresDataVolume}`, `<name>_${DwStack.storageDataVolume}`)
/// or by a secret store, `~/.config/<name>/${DwSecretStore.fileName}` — the
/// store alone names a stack whose database is external. Matched on whole
/// suffixes, not on a prefix: `shop_eu_postgres_data` belongs to `shop_eu`,
/// not to `shop`.
///
/// **Passes** when [projectName] is among the stacks (it is ours, whatever
/// else shares the host), or when there is no stack at all (a fresh server).
/// **Fails** when there are stacks and none of them is ours, naming them: the
/// shape of a repository move without `project:`, and the one case where a
/// deploy would quietly start an empty second stack.
///
/// [volumeListing] and [configDirListing] are read line by line; a line that
/// belongs to the other listing is ignored, so one combined answer can be
/// passed as both.
DwDataVolumeVerdict judgeStackIdentity({
  required String projectName,
  required String environment,
  required String volumeListing,
  required String configDirListing,
}) {
  final stacks = <String>{};
  for (final line in volumeListing.split('\n').map((line) => line.trim())) {
    if (line.isEmpty || line.contains('/')) continue;
    for (final kind in const [
      DwStack.postgresDataVolume,
      DwStack.storageDataVolume,
    ]) {
      final suffix = '_$kind';
      if (line.endsWith(suffix) && line.length > suffix.length) {
        stacks.add(line.substring(0, line.length - suffix.length));
      }
    }
  }
  for (final line in configDirListing.split('\n').map((line) => line.trim())) {
    final segments = line.split('/');
    if (segments.length >= 2 &&
        segments.last == DwSecretStore.fileName &&
        segments[segments.length - 2].isNotEmpty) {
      stacks.add(segments[segments.length - 2]);
    }
  }

  if (stacks.contains(projectName)) {
    return DwDataVolumeVerdict.pass('"$projectName" runs on this server');
  }
  if (stacks.isEmpty) {
    return const DwDataVolumeVerdict.pass(
      'no stack on this server yet — a fresh server',
    );
  }
  final others = stacks.toList()..sort();
  final pin = others.length == 1
      ? '"project: ${others.single}"'
      : '"project:" to its old name (one of ${others.join(', ')})';
  return DwDataVolumeVerdict.fail(
    'no "$projectName" stack on this server, but ${others.join(', ')} '
    '${others.length == 1 ? 'exists' : 'exist'}. If this is the same project '
    'after a repo move, set $pin under $environment in '
    '${DwDeployTarget.configRelativePath}. If it really is a second project '
    'on this host, run "dartway deploy setup --env $environment --new-stack".',
  );
}
