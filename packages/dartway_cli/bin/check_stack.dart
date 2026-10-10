import 'dart:io';

import 'package:args/args.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/project_layout.dart';

/// The Studio check image's entry point. Reads only the mounted checkout;
/// neither SSH credentials nor a writable package cache are needed.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      defaultsTo: '/project',
      help: 'Read-only project checkout.',
    )
    ..addOption('env', help: 'Kamal destination: stage or prod.')
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln(parser.usage);
      return;
    }
    final environment = switch (args.option('env')) {
      'stage' => 'staging',
      'prod' => 'production',
      _ => throw ArgumentError('Specify --env stage or --env prod.'),
    };
    final root = Directory(args.option('project')!);
    final layout = ProjectLayout.detect(root);
    final target = DwDeployTarget.load(
      projectRoot: root,
      environment: environment,
    );
    final stack = DwStack(
      projectRoot: root,
      target: target,
      serverPackage: layout.serverPackage,
      flutterPackage: layout.flutterPackage,
    );
    final probe = DwOutsideProbe();
    final checks = [
      () => probe.health(stack.apiOrigin),
      () => probe.health(stack.appOrigin),
      () => probe.liveUpgrade(stack.apiOrigin),
      () => probe.liveUpgrade(stack.appOrigin, browserOrigin: stack.appOrigin),
      () => probe.appIndex(stack.appOrigin),
      () => probe.webCache(stack.appOrigin),
      if (stack.storageOrigin case final origin?)
        () => probe.storageVisibility(
          storageOrigin: origin,
          publicBucket: stack.publicBucketName,
          privateBucket: stack.privateBucketName,
        ),
    ];
    for (final check in checks) {
      final result = await check();
      stdout.writeln(result);
      if (!result.passed) exitCode = 1;
    }
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
