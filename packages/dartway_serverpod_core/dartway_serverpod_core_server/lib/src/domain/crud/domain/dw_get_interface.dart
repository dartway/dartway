import 'package:serverpod/serverpod.dart';

abstract class DwGetConfigInterface<T extends TableRow> {
  final Future<Expression?> Function(Session session)? accessFilter;
  final Include? include;
  final List<Order>? defaultOrderByList;

  /// Whether a caller who is not signed in may reach this operation.
  ///
  /// Defaults to `false`: a CRUD endpoint is reachable without a session, so
  /// without this gate an unset `accessFilter` — or one returning `null` —
  /// exposes the whole table to the internet. Not configured means not allowed.
  ///
  /// Set it to `true` deliberately, for data that genuinely precedes the login
  /// screen: a public catalog, app settings the splash screen reads. The word
  /// is greppable and shows up in review, which `null` never did.
  final bool allowAnonymous;
  // final Future<List<TableRow>> Function(Session session, List<T> models)?
  //     additionalModelsFetchFunction;

  const DwGetConfigInterface({
    required this.accessFilter,
    this.allowAnonymous = false,
    this.include,
    this.defaultOrderByList,
    // this.additionalModelsFetchFunction,
  });

  Future<Expression?> getWhereExpression(
    Session session, {
    required Expression? whereClause,
  }) async {
    final accessFilterExpression = await accessFilter?.call(session);

    if (accessFilterExpression == null) return whereClause;
    if (whereClause == null) return accessFilterExpression;

    return whereClause & accessFilterExpression;
  }
}
