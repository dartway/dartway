import 'package:dartway_core_shared/dartway_core_shared.dart';

/// Whether an installed build knows this update group, including deletions.
/// Internal calls and protocols without a project version have no client gate.
bool dwClientKnowsUpdate(
  DwWireProtocol protocol,
  DwContractVersion? client,
  DwWireObject item,
) {
  if (protocol.contractVersion == null || client == null) return true;
  final name = item is DwDeletedObject ? item.typeName : item.dwTypeName;
  final since = protocol.entryNamed(name)?.since;
  return since == null || !(client < since);
}
