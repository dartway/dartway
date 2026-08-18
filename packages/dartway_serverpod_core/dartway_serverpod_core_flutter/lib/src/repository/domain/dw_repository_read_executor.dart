import 'dw_repo_query_key.dart';

/// Executes a repository read for the current online-only data layer.
///
/// Snapshot support can replace this executor later while retaining the exact
/// request identity and online request contract.
abstract interface class DwRepositoryReadExecutor {
  const DwRepositoryReadExecutor();

  Future<Response> execute<Model, Response>({
    required DwRepoQueryKey<Model> queryKey,
    required Future<Response> Function() onlineRequest,
  });
}

/// The default read executor: every read reaches the backend unchanged.
class DwOnlineRepositoryReadExecutor implements DwRepositoryReadExecutor {
  const DwOnlineRepositoryReadExecutor();

  @override
  Future<Response> execute<Model, Response>({
    required DwRepoQueryKey<Model> queryKey,
    required Future<Response> Function() onlineRequest,
  }) => onlineRequest();
}
