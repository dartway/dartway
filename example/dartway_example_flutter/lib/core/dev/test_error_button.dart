import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

/// Dev-only error stand: each item exercises one interception point of the
/// error pipeline, so the resulting report (route, features, action, stack)
/// can be inspected in the console.
class TestErrorButton extends StatelessWidget {
  const TestErrorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Throw a test error',
      icon: const Icon(Icons.bug_report_outlined),
      onSelected: (value) {
        switch (value) {
          case 'sync':
            throw StateError('Test sync error (zone)');
          case 'async':
            Future<void>.microtask(
              () => throw StateError('Test async error (zone)'),
            );
          case 'action':
            dw.action(
              (_) => throw StateError('Test action error'),
              label: 'testErrorAction',
            )(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'sync', child: Text('Throw sync error')),
        PopupMenuItem(value: 'async', child: Text('Throw async error')),
        PopupMenuItem(value: 'action', child: Text('Fail a DwUiAction')),
      ],
    );
  }
}
