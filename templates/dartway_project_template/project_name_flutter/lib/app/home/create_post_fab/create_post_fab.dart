import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/app/home/create_post_fab/widgets/create_post_bottom_sheet.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';

class CreatePostFab extends StatelessWidget {
  const CreatePostFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SignedInUserScope<UserProfile>(
            userProfileProvider: userProfileProvider,
            child: const CreatePostBottomSheet(),
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}
