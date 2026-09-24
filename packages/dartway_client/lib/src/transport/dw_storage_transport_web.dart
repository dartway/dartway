import 'dw_storage_transport.dart';
import 'dw_xhr_storage_transport.dart';

/// On the web, `XMLHttpRequest` by default: `DwHttpStorageTransport`'s
/// browser `fetch` cannot report real upload progress at all (#309).
DwStorageTransport dwDefaultStorageTransport() => const DwXhrStorageTransport();
