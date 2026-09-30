import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/content/content_rows.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Content rows → the data objects clients see.
abstract final class ContentObjects {
  /// [author] is the author of every post, when the caller holds it.
  static Future<List<NewsPost>> news(
    DwDatabaseHandle db,
    List<NewsPostRow> rows, {
    UserProfileRow? author,
  }) async {
    final authors = author != null
        ? {author.id!: author}
        : await ProfileObjects.rowsById(db, rows.map((p) => p.authorProfileId));
    return [
      for (final row in rows)
        NewsPost(
          id: row.id!,
          title: row.title,
          text: row.text,
          author: ProfileObjects.person(authors[row.authorProfileId]!),
          createdAt: row.createdAt,
        ),
    ];
  }

  static AppSetting setting(AppSettingRow row) =>
      AppSetting(id: row.key, value: row.value);
}
