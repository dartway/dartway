import 'package:serverpod/serverpod.dart';

abstract class DwGetConfigInterface<T extends TableRow> {
  final Future<Expression?> Function(
    Session session,
  )? accessFilter;
  final Include? include;
  final List<Order>? defaultOrderByList;
  // final Future<List<TableRow>> Function(Session session, List<T> models)?
  //     additionalModelsFetchFunction;

  const DwGetConfigInterface({
    required this.accessFilter,
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
