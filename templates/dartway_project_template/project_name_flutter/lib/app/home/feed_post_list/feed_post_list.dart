import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';

import 'widgets/feed_post_card.dart';

class FeedPostList extends ConsumerWidget {
  const FeedPostList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<FeedPost>().dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (feedPosts) {
            if (feedPosts.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.post_add,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create your first post using the + button!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feedPosts.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FeedPostCard(
                  post: feedPosts[index],
                ),
              ),
            );
          },
        );
  }
}
