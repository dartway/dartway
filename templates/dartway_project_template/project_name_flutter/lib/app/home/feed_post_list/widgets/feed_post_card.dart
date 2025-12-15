import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

class FeedPostCard extends StatelessWidget {
  final FeedPost post;

  const FeedPostCard({required this.post, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    post.authorProfile?.firstName.isNotEmpty == true
                        ? post.authorProfile!.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.body(
                        post.authorProfile?.firstName.isNotEmpty == true
                            ? post.authorProfile!.firstName
                            : 'Anonymous',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppText.caption(
                        _formatDate(post.createdAt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(12),

            // Post title
            AppText.title(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),

            // Post content
            AppText.body(
              post.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
