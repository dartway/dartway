// Run with the created project's server package configuration.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_client/dartway_client.dart';
import 'package:probe_dw_shared/probe_dw_shared.dart';

Future<void> main(List<String> args) async {
  final session = DwAuthSession.fromJson(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>,
  );
  final observer = DwAppClient(
    protocol: appProtocol,
    baseUrl: Uri.parse('https://api.probe.stageserver.ru'),
    appVersion: '0.1.0+1',
    tokenStore: DwMemoryTokenStore(session),
  );
  final author = DwAppClient(
    protocol: appProtocol,
    baseUrl: Uri.parse('https://api.probe.stageserver.ru'),
    appVersion: '0.1.0+1',
    tokenStore: DwMemoryTokenStore(session),
  );
  await observer.start();
  await author.start();
  final received = <String>{};
  final emitted = <String>[];
  final states = <String>[];
  final status = observer.connectionStatusStream.listen((state) {
    states.add(state.name);
  });
  final updates = observer
      .listen([DwLiveChannel.forAccount(ProbeDwChannel.profile, session.id)])
      .listen((value) {
        if (value is UserProfile) {
          received.add(value.firstName);
          stdout.writeln(
            jsonEncode({
              'event': 'received',
              'name': value.firstName,
              'time': DateTime.now().toUtc().toIso8601String(),
            }),
          );
        }
      });
  for (
    var attempt = 0;
    observer.connectionStatus != DwConnectionStatus.connected && attempt < 100;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await Future<void>.delayed(const Duration(seconds: 1));
  stdout.writeln('ready');
  for (var index = 0; index < int.parse(args[1]); index++) {
    final name = 'probe-$index';
    final result = await author.command(UpdateMyProfile(firstName: name));
    if (result is DwCallOk<UserProfile>) {
      emitted.add(name);
      stdout.writeln(
        jsonEncode({
          'event': 'emitted',
          'name': name,
          'time': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await Future<void>.delayed(const Duration(seconds: 5));
  stdout.writeln(
    jsonEncode({
      'emitted': emitted.length,
      'received': received.length,
      'missing': emitted.where((name) => !received.contains(name)).toList(),
      'states': states,
    }),
  );
  await updates.cancel();
  await status.cancel();
  await observer.stop();
  await author.stop();
}
