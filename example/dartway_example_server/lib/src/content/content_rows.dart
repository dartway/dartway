import 'package:dartway_core_server/dartway_core_server.dart';

part 'content_rows.dw.dart';

@DwSqlTable(
  'news_post',
  indexes: [
    DwTableIndex(['createdAt']),
  ],
)
final class NewsPostRow extends DwTableRow with _$NewsPostRow {
  const NewsPostRow({
    required this.id,
    required this.authorProfileId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  @override
  final int id;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String title;
  final String text;
  final DateTime createdAt;

  static const tableDef = NewsPostTable();
}
