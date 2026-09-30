import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_example_shared/src/dartway_example_channel.dart';
import 'package:dartway_example_shared/src/dartway_example_refusal.dart';
import 'package:dartway_example_shared/src/profile.dart';

part 'content.dw.dart';

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

/// The news feed, newest first, read page by page and live: a post published
/// anywhere is put in its place, a removed one disappears.
final class ListNews extends DwPageRequest<NewsPost> with _$ListNews {
  const ListNews() : super(pageSize: 20);

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayExampleChannel.news),
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
      DwCallRefusal(DartwayExampleRefusal.titleRequired, field: 'title'),
    if (text.trim().isEmpty)
      DwCallRefusal(DartwayExampleRefusal.textRequired, field: 'text'),
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

/// The club's settings: one value, edited by admins, read live by every
/// signed-in member. Every field has a default, which is the value while
/// nobody has saved one — the server stores only what differs from it.
final class ClubSettings extends DwDataObject with _$ClubSettings {
  const ClubSettings({
    this.clubName = 'DartWay Fitness',
    this.bookingEnabled = true,
    this.supportPhone,
  });

  /// There is one: its identity is fixed.
  @override
  String get id => 'club';

  /// The club's name.
  final String clubName;

  /// Whether the schedule is open for booking.
  final bool bookingEnabled;

  /// The phone members call when something goes wrong, or `null` for none.
  final String? supportPhone;
}

final class GetClubSettings extends DwSingleRequest<ClubSettings>
    with _$GetClubSettings {
  const GetClubSettings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayExampleChannel.settings),
  ];
}

/// Changes the settings it names and leaves the rest. Admins only.
final class SaveClubSettings extends DwActionCommand<ClubSettings>
    with _$SaveClubSettings
    implements DwSelfValidating {
  const SaveClubSettings({
    this.clubName,
    this.bookingEnabled,
    this.supportPhone = const DwFieldPatch.keep(),
  });

  final String? clubName;
  final bool? bookingEnabled;

  /// Nullable in the settings, so a patch: it can be cleared.
  final DwFieldPatch<String> supportPhone;

  @override
  List<DwCallRefusal> validate() => [
    if (clubName case final name? when name.trim().isEmpty)
      DwCallRefusal(DartwayExampleRefusal.clubNameRequired, field: 'clubName'),
  ];
}
