import 'dw_storage_transport.dart';

/// Off the web, `DwHttpStorageTransport` already streams the body at the
/// network's pace and reports real progress through
/// [DwStoragePut.reportSent] on its own — nothing else is needed.
DwStorageTransport dwDefaultStorageTransport() => DwHttpStorageTransport();
