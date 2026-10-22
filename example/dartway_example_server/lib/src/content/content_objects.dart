import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/content/content_rows.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Content rows → the data objects clients see.
abstract final class ContentObjects {
  /// [author] is the author of every post, when the caller holds it.
  static List<NewsPost> news(List<NewsPostRow> rows, {UserProfileRow? author}) {
    return [
      for (final row in rows)
        NewsPost(
          id: row.id,
          title: row.title,
          text: row.text,
          author: ProfileObjects.person(
            author ?? row.one(NewsPostRow.tableDef.authorProfile),
          ),
          createdAt: row.createdAt,
        ),
    ];
  }
}
