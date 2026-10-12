import 'dart:convert';

import 'ssh_runner.dart';

/// Whitelisted runtime metadata: no environment, health logs or credentials.
final class DwKamalRuntimeState {
  DwKamalRuntimeState(
    this.containers,
    this.routes,
    this.congestion,
    this.subnets,
  );
  final List<DwKamalContainerInfo> containers;
  final Map routes;
  final String congestion;
  final List<String> subnets;

  factory DwKamalRuntimeState.parse(String output) {
    final parts = output.split('\nDW_KAMAL_');
    if (parts.length != 4 ||
        !parts[1].startsWith('ROUTES\n') ||
        !parts[2].startsWith('CONGESTION\n') ||
        !parts[3].startsWith('NETWORK\n')) {
      throw const FormatException('incomplete native inspection');
    }
    final containers = parts[0]
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => DwKamalContainerInfo(jsonDecode(line) as List))
        .toList();
    return DwKamalRuntimeState(
      containers,
      jsonDecode(parts[1].substring('ROUTES\n'.length)) as Map,
      parts[2].substring('CONGESTION\n'.length).trim(),
      (jsonDecode(parts[3].substring('NETWORK\n'.length)) as List)
          .map((config) => (config as Map)['Subnet'] as String)
          .toList(),
    );
  }
}

final class DwKamalContainerInfo {
  DwKamalContainerInfo(this.fields) {
    if (fields.length != 11 ||
        fields[0] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fields[0] as String) ||
        !const [0, 1].contains(fields[3]) ||
        !const [
          'none',
          'starting',
          'healthy',
          'unhealthy',
        ].contains(fields[4])) {
      throw const FormatException('invalid container metadata');
    }
  }
  final List fields;
  String get identity => fields[0] as String;
  String get name => (fields[1] as String).replaceFirst(RegExp(r'^/'), '');
  String get image => fields[2] as String;
  bool get running => fields[3] == 1;
  bool get healthy => fields[4] == 'none' || fields[4] == 'healthy';
  String? get service => fields[5] as String?;
  String? get role => fields[6] as String?;
  String? get destination => fields[7] as String?;
  List<DwKamalMountInfo> get mounts => (fields[8] as List)
      .map((mount) => DwKamalMountInfo(mount as List))
      .toList();
  bool isTarget(String target, int port) {
    final uri = Uri.parse(target.contains('://') ? target : 'http://$target');
    return uri.port == port &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        uri.scheme == 'http' &&
        [
          identity,
          identity.substring(0, 12),
          name,
          fields[9],
          fields[10],
        ].contains(uri.host);
  }
}

final class DwKamalMountInfo {
  DwKamalMountInfo(this.fields) {
    if (fields.length != 5 ||
        fields.take(4).any((value) => value is! String) ||
        !const [0, 1].contains(fields[4])) {
      throw const FormatException('invalid mount metadata');
    }
  }
  final List fields;
  String get type => fields[0] as String;
  String get source => fields[1] as String;
  String get destination => fields[2] as String;
  String get name => fields[3] as String;
  bool get writable => fields[4] == 1;
}

/// Inspects only selected services, the native proxy and its network. Mount
/// access modes are explicit numeric flags and validated before use.
String nativeKamalInspectionScript(List<String> services) =>
    '''
set -eu
for service in ${services.map(DwSshRunner.quote).join(' ')}; do
  ids=\$(docker ps -aq --filter "label=service=\$service")
  if [ -n "\$ids" ]; then
    docker inspect --format ${DwSshRunner.quote(_inspectionTemplate)} \$ids
  fi
done
printf '\\nDW_KAMAL_ROUTES\\n'
docker exec kamal-proxy kamal-proxy list --json
printf '\\nDW_KAMAL_CONGESTION\\n'
docker exec kamal-proxy cat /proc/sys/net/ipv4/tcp_congestion_control
printf '\\nDW_KAMAL_NETWORK\\n'
docker network inspect kamal --format '{{json .IPAM.Config}}'
''';

const _inspectionTemplate =
    r'''[{{json .Id}},{{json .Name}},{{json .Config.Image}},{{if .State.Running}}1{{else}}0{{end}},{{with index .State "Health"}}{{json .Status}}{{else}}"none"{{end}},{{json (index .Config.Labels "service")}},{{json (index .Config.Labels "role")}},{{json (index .Config.Labels "destination")}},[{{range $index,$mount := .Mounts}}{{if $index}},{{end}}[{{json $mount.Type}},{{json $mount.Source}},{{json $mount.Destination}},{{if index $mount "Name"}}{{json (index $mount "Name")}}{{else}}""{{end}},{{if $mount.RW}}1{{else}}0{{end}}]{{end}}],{{with index .NetworkSettings.Networks "kamal"}}{{json .IPAddress}},{{json .GlobalIPv6Address}}{{else}}"",""{{end}}]''';
