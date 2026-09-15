import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';

import '../handlers/dw_call_handler.dart';
import '../jobs/dw_job_queue.dart';

/// A framework satellite plugged into a server: push delivery, and whatever
/// else ships its own tables, calls and jobs outside the core package.
///
/// A module brings:
///
/// - [migrations], applied under its own [namespace] after the framework's
///   (`dw`) and before the project's (`app`) — a module's tables reference
///   accounts, and a project's may reference a module's;
/// - [handlers] for the calls it answers. Their classes must be registered
///   in the project's protocol (the module says which in [problems]), and a
///   project may not answer them itself;
/// - [jobs], named `dw.<namespace>.…`;
/// - [problems] — what is wrong with its configuration against the server's
///   protocol; any problem refuses startup with the server's own;
/// - [close], called once the server has stopped taking calls and jobs.
///
/// Handlers reach their module's runtime through `ctx.module<M>()`, which
/// is how a module offers a context extension (`ctx.push`) without a global.
abstract class DwServerModule {
  const DwServerModule();

  /// The migration namespace and the middle of every job name:
  /// lower-case letters, digits and `_`, not `dw` or `app`.
  String get namespace;

  List<DwDatabaseMigration> get migrations => const [];

  List<DwCallHandler> get handlers => const [];

  List<DwJobDefinition> get jobs => const [];

  /// Problems with this module in a server speaking [protocol]; empty when
  /// it can start.
  List<String> problems(DwWireProtocol protocol) => const [];

  /// Releases what the module holds (HTTP clients). The server calls it on
  /// stop, and when a start fails after the module was accepted.
  Future<void> close() async {}
}
