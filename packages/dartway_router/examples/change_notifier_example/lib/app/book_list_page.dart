import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';

class BookListPage extends StatelessWidget {
  const BookListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book List')),
      body: Column(
        children: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            .map(
              (e) => Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.goNamed(
                    AppRoutes.bookDetail.name,
                    pathParameters: AppParams.bookId.set(e),
                  ),
                  child: Text('Book $e'),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
