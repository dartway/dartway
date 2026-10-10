import 'ssh_runner.dart';

/// Reads size and available space in KiB on the filesystem containing a path.
/// The path is carried separately from df's filesystem and mount names.
const dwDiskSpaceFunction = r'''
dw_disk_space() {
  df -Pk "$1" | awk -v path="$1" 'NR == 2 { printf "%s\t%s\t%s\n", path, $2, $4; found=1 } END { if (!found) exit 1 }'
}
''';

/// Docker can be unavailable after a step dies; still inspect its usual root.
const dwDockerRootScript = r'''
dw_docker_root=$(docker info -f '{{.DockerRootDir}}' 2>/dev/null) || dw_docker_root=
[ -n "$dw_docker_root" ] || dw_docker_root=/var/lib/docker
''';

/// A df observation, with units converted from KiB to bytes.
class DwDiskSpace {
  const DwDiskSpace(this.path, this.sizeBytes, this.freeBytes);

  final String path;
  final int sizeBytes;
  final int freeBytes;

  static DwDiskSpace? parse(String line) {
    final fields = line.trim().split('\t');
    if (fields.length != 3) return null;
    final size = int.tryParse(fields[1]);
    final free = int.tryParse(fields[2]);
    if (size == null || free == null || size < 0 || free < 0) return null;
    return DwDiskSpace(fields[0], size * 1024, free * 1024);
  }

  String get free => _format(freeBytes);
  String get description => '$path: $free free of ${_format(sizeBytes)}';

  static String _format(int bytes) {
    for (final unit in [(1024 * 1024 * 1024, 'GiB'), (1024 * 1024, 'MiB')]) {
      if (bytes >= unit.$1) {
        return '${(bytes / unit.$1).toStringAsFixed(1)} ${unit.$2}';
      }
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KiB';
  }
}

/// Read-only guard shared by deploy run and deploy check.
Future<DwSshResult> dwCheckBuildDiskSpace({
  required DwSshRunner ssh,
  required String deployUser,
  required String minimum,
  required int minimumBytes,
}) async {
  final result = await ssh.runAs(deployUser, '''
$dwDiskSpaceFunction
$dwDockerRootScript
dw_disk_space "\$dw_docker_root"
''');
  if (!result.ok) return result;
  final space = DwDiskSpace.parse(result.stdout);
  if (space == null) {
    return const DwSshResult(
      exitCode: 1,
      stdout: '',
      stderr: "Cannot read free space on Docker's data root.",
    );
  }
  if (space.freeBytes < minimumBytes) {
    return DwSshResult(
      exitCode: 1,
      stdout: '',
      stderr:
          "Docker's data root ${space.path} has ${space.free} free; "
          'a build needs at least $minimum. Free space or lower min_free_disk '
          'in deploy/config.yaml.',
    );
  }
  return DwSshResult(exitCode: 0, stdout: space.description, stderr: '');
}
