import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';
import 'people.dart';

part 'news.dw.dart';

final class NewsPost extends DwDataObject with _$NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  @override
  final int id;
  final String title;
  final String text;
  final PersonCard author;
  final DateTime createdAt;
}

/// The news feed, newest first and live: a post published anywhere is put in
/// its place, a removed one disappears.
final class ListNews extends DwListRequest<NewsPost> with _$ListNews {
  const ListNews();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.news),
  ];

  @override
  int Function(NewsPost a, NewsPost b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

/// Publishes a post authored by the caller. Staff only.
final class PublishNews extends DwActionCommand<NewsPost>
    with _$PublishNews
    implements DwSelfValidating {
  const PublishNews({required this.title, required this.text});

  final String title;
  final String text;

  @override
  List<DwCallRefusal> validate() => [
    if (title.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.titleRequired, field: 'title'),
    if (text.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.textRequired, field: 'text'),
  ];
}

/// What a news notification carries to the app: the post it is about. The
/// app opens the news page on it.
final class NewsAlert extends DwDataObject with _$NewsAlert {
  const NewsAlert({required this.id});

  /// The post's id.
  @override
  final int id;
}

/// Removes a post. Staff only.
final class RemoveNews extends DwActionCommand<void> with _$RemoveNews {
  const RemoveNews({required this.postId});

  final int postId;
}
