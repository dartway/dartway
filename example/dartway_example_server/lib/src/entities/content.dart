import 'package:dartway_core_server/dartway_core_server.dart';

part 'content.dw.dart';

@DwSqlTable(
  'news_post',
  indexes: [
    DwTableIndex(['createdAt']),
  ],
)
final class NewsPostRow extends DwTableRow with _$NewsPostRow {
  const NewsPostRow({
    this.id,
    required this.authorProfileId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String title;
  final String text;
  final DateTime createdAt;

  static const table = NewsPostTable();
}

@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow with _$AppSettingRow {
  const AppSettingRow({this.id, required this.key, required this.value});

  @override
  final int? id;

  @DwUniqueColumn()
  final String key;

  final String value;

  static const table = AppSettingTable();
}
