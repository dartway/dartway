import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/app/news/widgets/create_news_post_sheet.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class CreateNewsPostFab extends StatelessWidget {
  const CreateNewsPostFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.showAppBottomSheet(
        child: const CreateNewsPostSheet(),
      ),
      child: const Icon(Icons.add),
    );
  }
}
