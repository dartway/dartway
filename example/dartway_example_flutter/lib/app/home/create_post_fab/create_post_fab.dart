import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/app/home/create_post_fab/widgets/create_post_bottom_sheet.dart';

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
          builder: (context) => const CreatePostBottomSheet(),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}
