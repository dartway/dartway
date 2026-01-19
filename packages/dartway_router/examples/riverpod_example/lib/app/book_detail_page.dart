import 'package:flutter/material.dart';

import '../router/app_router.dart';

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final itemId = AppParams.bookId.fromPath(context);

    return Scaffold(
      appBar: AppBar(title: Text('Item $itemId')),
      body: Center(child: Text('Item Detail for ID: $itemId')),
    );
  }
}
