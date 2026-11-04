import 'dart:io';

import 'package:args/args.dart';
import 'package:dartway_cli/src/deploy/kamal_contract.dart';
import 'package:dartway_cli/src/deploy/outside_probe.dart';

/// The Studio check image's entry point. Reads only the mounted checkout's
/// `deploy/studio.yml` and the environment's domains and storage mode from
/// the variables the manifest's `check.environment` names; neither SSH
/// credentials nor a writable package cache are needed.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      defaultsTo: '/project',
      help: 'Read-only project checkout.',
    )
    ..addOption('env', help: "The environment's name in Studio.")
    ..addOption('version', help: 'Required immutable deployment SHA.')
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln(parser.usage);
      return;
    }
    final environment = args.option('env');
    if (environment == null) {
      throw ArgumentError('Specify --env <environment>.');
    }
    final root = Directory(args.option('project')!);
    final version = args.option('version');
    if (version == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(version)) {
      throw ArgumentError('Specify --version <full deployment SHA>.');
    }
    final stack = DwKamalEnvironment.stack(
      projectRoot: root,
      manifest: DwKamalManifest.load(root),
      name: environment,
      variables: Platform.environment,
      check: true,
    );
    final probe = DwOutsideProbe();
    final checks = [
      () => probe.health(stack.apiOrigin, version: version),
      () => probe.health(stack.appOrigin, path: '/dw/health', version: version),
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
      if (stack.storageOrigin case final origin?)
        for (final bucket in [stack.publicBucketName, stack.privateBucketName])
          () => probe.storageCors(
            storageOrigin: origin,
            bucket: bucket,
            appOrigin: stack.appOrigin,
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
