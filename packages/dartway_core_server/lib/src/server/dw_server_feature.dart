import '../channels/dw_channel_rule.dart';
import '../handlers/dw_call_handler.dart';
import '../jobs/dw_job_queue.dart';
import '../routes/dw_http_route.dart';

/// One area of a project's server — its calls, live channels, jobs and
/// doors, declared together in the folder the area lives in.
///
/// A project lists its features and nothing else: `DwAppServer(features:
/// [ProfileFeature.server, ChatFeature.server])`. The area's pieces used to be
/// spread over the server's own lists by hand — handlers in one, channel rules
/// in another, jobs in a third — and every project grouped them differently;
/// one kept a feature's channel rules with the feature, the next inline in a
/// shared file, in the same codebase.
///
/// [name] is the feature's folder under `lib/src/` (`chat`, `daily_plan`),
/// which `dartway check` holds to the declaring file
/// (`lib/src/chat/chat_feature.dart`).
final class DwServerFeature {
  const DwServerFeature(
    this.name, {
    this.handlers = const [],
    this.channels = const [],
    this.jobs = const [],
    this.routes = const [],
  });

  /// Lower-case letters, digits and `_`, starting with a letter.
  final String name;
  final List<DwCallHandler> handlers;
  final List<DwChannelRule> channels;
  final List<DwJobDefinition> jobs;
  final List<DwHttpRoute> routes;

  /// Whether [name] is a feature name.
  static bool isValidName(String name) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);

  @override
  String toString() => 'DwServerFeature($name)';
}
