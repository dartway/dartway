import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the news feed sends.
abstract final class NewsCommands {
  /// Publishes a post. Staff only — the server's rule; it reaches the feed of
  /// every member, and a push to those who agreed to it.
  static Future<DwCallResult<NewsPost>> publish({
    required String title,
    required String text,
  }) => dw.command(PublishNews(title: title.trim(), text: text.trim()));
}
