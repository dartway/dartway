// ignore_for_file: unused_import
import 'deploy_target.dart';
import 'stack.dart';

/// One data-volume guard, judged the same way whether it runs from `deploy
/// setup` or `deploy run` — the reason it lives here instead of inline in
/// either command.
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
