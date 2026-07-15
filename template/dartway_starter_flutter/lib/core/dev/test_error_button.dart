import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';

/// Dev-only error stand: each item exercises one interception point of the
/// error pipeline, so the resulting alert (route, features, action/call,
/// top-8 stack) can be inspected in the console / Telegram.
class TestErrorButton extends ConsumerWidget {
  const TestErrorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          case 'call':
            // A server call that fails on the backend → onFailedCall path
            // with `endpoint.method` attached.
            dw.endpointCaller.dwCrud.getOne(
              className: 'NoSuchModel',
              filter: const DwBackendFilter<int>.value(
                type: DwBackendFilterType.equals,
                fieldName: 'id',
                fieldValue: -1,
              ),
              apiGroup: 'default',
            );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'sync', child: Text('Throw sync error')),
        PopupMenuItem(value: 'async', child: Text('Throw async error')),
        PopupMenuItem(value: 'action', child: Text('Fail a DwUiAction')),
        PopupMenuItem(value: 'call', child: Text('Fail a server call')),
      ],
    );
  }
}
