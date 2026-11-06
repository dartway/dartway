/// Marks a project-contract member that is being retired.
///
/// [since] is the shared package contract version in which clients first
/// stopped depending on the member. The member may be removed only after a
/// store baseline containing this mark has been committed.
final class DwDeprecated {
  const DwDeprecated({required this.since});

  final String since;
}
