import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';
import 'people.dart';

part 'news.dw.dart';

final class NewsPostView extends DwDataObject with _$NewsPostView {
  const NewsPostView({
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
  final PersonView author;
  final DateTime createdAt;
}

/// The news feed, newest first.
final class ListNews extends DwListRequest<NewsPostView> with _$ListNews {
  const ListNews();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.news)];

  @override
  int Function(NewsPostView a, NewsPostView b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

/// Publishes a post authored by the caller. Staff only.
final class PublishNews extends DwCommand<NewsPostView> with _$PublishNews {
  const PublishNews({required this.title, required this.text});

  final String title;
  final String text;
}

/// Removes a post. Staff only.
final class RemoveNews extends DwCommand<void> with _$RemoveNews {
  const RemoveNews({required this.postId});

  final int postId;
}
