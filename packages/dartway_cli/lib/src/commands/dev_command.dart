import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../dev/dev_proxy.dart';
import '../dev/web_directory.dart';
import '../project_layout.dart';

/// Local development in the deployed shape (D-039): the web app and the API on
/// one origin, as production's Nginx puts them.
class DevCommand extends Command<int> {
  DevCommand() {
    addSubcommand(DevProxyCommand());
    addSubcommand(DevWebCommand());
  }

  @override
  String get name => 'dev';

  @override
  String get description =>
      'Local development on one origin: the web app and the API behind a '
      'proxy shaped like the deployment.';
}

const _defaultApi = 'http://localhost:8080';
const _defaultPort = '8000';

void _addProxyOptions(ArgParser parser) {
  parser
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: _defaultPort,
      help: 'Port of the origin to open in the browser.',
    )
    ..addOption(
      'api',
      defaultsTo: _defaultApi,
      help:
          'The running server: /dw/* (the live socket included) and /health '
          'go here.',
    )
    ..addMultiOption(
      'api-path',
      help:
          'A project door (DwRoute) that goes to the server too, e.g. '
          '--api-path /mcp --api-path /github. Repeatable.',
    );
}

int _portOption(Command<int> command, ArgResults results) {
  final raw = results.option('port')!;
  final port = int.tryParse(raw);
  if (port == null || port < 0 || port > 65535) {
    command.usageException('--port must be a port number, got "$raw".');
  }
  return port;
}

/// An `http://host:port` base from [option], or a usage error naming it.
Uri _originOption(Command<int> command, String option, String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host.isEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery) {
    command.usageException(
      '--$option must be an http origin such as http://localhost:8080, '
      'got "$raw".',
    );
  }
  return Uri(scheme: 'http', host: uri.host, port: uri.port);
}

/// Completes on the first Ctrl+C (or SIGTERM, where the platform has it).
Future<void> _interrupted() {
  final completer = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  void done(ProcessSignal _) {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    if (!completer.isCompleted) completer.complete();
  }

  subscriptions.add(ProcessSignal.sigint.watch().listen(done));
  if (!Platform.isWindows) {
    subscriptions.add(ProcessSignal.sigterm.watch().listen(done));
  }
  return completer.future;
}

void _printBanner(DwDevProxy proxy, {required String title}) {
  stdout
    ..writeln()
    ..writeln(title)
    ..writeln('  Open  ${proxy.origin}')
    ..writeln()
    ..writeln('  ${proxy.describe().join('\n  ')}')
    ..writeln()
    ..writeln(
      '  The app is built against this origin: DW_BACKEND_URL=${proxy.origin}.',
    )
    ..writeln(
      '  Open it as written — to a browser 127.0.0.1 is another origin, and '
      'the calls would be cross-origin.',
    )
    ..writeln();
}

/// A one-line note when nothing listens at [api] yet — not an error: the
/// server is often started after the proxy.
Future<void> _noteApiReachability(Uri api) async {
  try {
    final socket = await Socket.connect(
      api.host,
      api.port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
  } on Object {
    stdout.writeln(
      '  Nothing answers at $api yet: start the server, and calls will reach '
      'it once it listens.',
    );
  }
}

Future<bool> _startProxy(DwDevProxy proxy, int port) async {
  try {
    await proxy.start(port: port);
    return true;
  } on SocketException catch (error) {
    stderr.writeln(
      'Cannot listen on port $port: ${error.osError?.message ?? error.message}. '
      'Pass another one with --port.',
    );
    return false;
  }
}

/// `dartway dev proxy`: the origin alone, in front of servers started
/// elsewhere.
class DevProxyCommand extends Command<int> {
  DevProxyCommand() {
    _addProxyOptions(argParser);
    argParser
      ..addOption(
        'web',
        help:
            'The Flutter web dev server everything else goes to '
            '(`flutter run -d web-server --web-port 5000`).',
        defaultsTo: 'http://localhost:5000',
      )
      ..addOption(
        'web-dir',
        help:
            'Serve a built app instead (`flutter build web`), with the '
            'fallback to index.html and the cache headers the deployed web '
            'image uses.',
      );
  }

  @override
  String get name => 'proxy';

  @override
  String get description =>
      'Serve one origin: /dw/* and /health to the API, everything else to the '
      'Flutter web dev server or a built app.';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${results.rest.join(' ')}.');
    }
    final port = _portOption(this, results);
    final api = _originOption(this, 'api', results.option('api')!);
    final webDirOption = results.option('web-dir');
    if (results.wasParsed('web') && webDirOption != null) {
      usageException('Pass either --web or --web-dir, not both.');
    }

    final DwDevProxy proxy;
    if (webDirOption != null) {
      final directory = Directory(webDirOption);
      if (!directory.existsSync()) {
        stderr.writeln(
          'No directory at ${directory.absolute.path}: build the app first '
          '(flutter build web --dart-define=DW_BACKEND_URL=http://localhost:$port).',
        );
        return 1;
      }
      proxy = DwDevProxy(
        api: api,
        apiPaths: results.multiOption('api-path'),
        webDirectory: DwWebDirectory(
          directory,
          servingConfiguration: DwWebDirectory.projectServingConfiguration(
            directory,
          ),
        ),
      );
    } else {
      proxy = DwDevProxy(
        api: api,
        apiPaths: results.multiOption('api-path'),
        webServer: _originOption(this, 'web', results.option('web')!),
      );
    }

    if (!await _startProxy(proxy, port)) return 1;
    _printBanner(proxy, title: 'dartway dev proxy — one origin, as deployed');
    await _noteApiReachability(api);
    stdout.writeln('Ctrl+C to stop.');

    await _interrupted();
    stdout.writeln('\nStopping the proxy.');
    await proxy.stop();
    return 0;
  }
}

/// `dartway dev web`: `flutter run -d web-server` and the proxy in front of it,
/// started and stopped together.
class DevWebCommand extends Command<int> {
  DevWebCommand() {
    _addProxyOptions(argParser);
    argParser.addOption(
      'flutter',
      help:
          'The Flutter command to run. Defaults to the project\'s FVM SDK '
          '(.fvm/flutter_sdk), `fvm flutter` when the project pins one in '
          '.fvmrc, and `flutter` otherwise.',
    );
  }

  @override
  String get name => 'web';

  @override
  String get description =>
      'Run the Flutter web app behind the dev proxy: one command, one origin, '
      'hot reload included.';

  @override
  String get invocation =>
      'dartway dev web [--port 8000] [--api http://localhost:8080] '
      '[-- <flutter run arguments>]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final port = _portOption(this, results);
    final api = _originOption(this, 'api', results.option('api')!);
    final layout = _detectLayout();
    final flutterDir = layout.flutterPackageDir;
    if (!flutterDir.existsSync()) {
      stderr.writeln('No Flutter package at ${flutterDir.path}.');
      return 1;
    }

    final webPort = await _freePort();
    final proxy = DwDevProxy(
      api: api,
      apiPaths: results.multiOption('api-path'),
      webServer: Uri(scheme: 'http', host: 'localhost', port: webPort),
    );
    if (!await _startProxy(proxy, port)) return 1;

    final (executable, prefix) = flutterCommand(
      override: results.option('flutter'),
      searched: [layout.root, flutterDir],
    );
    final arguments = dwFlutterRunArguments(
      webPort: webPort,
      backendUrl: proxy.origin,
      extra: results.rest,
    );
    stdout.writeln(
      'Starting `${[executable, ...prefix, ...arguments].join(' ')}` '
      'in ${p.relative(flutterDir.path)}',
    );

    final Process flutter;
    try {
      flutter = await Process.start(
        executable,
        [...prefix, ...arguments],
        workingDirectory: flutterDir.path,
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
    } on ProcessException catch (error) {
      await proxy.stop();
      stderr.writeln(
        'Could not start $executable: ${error.message}. '
        'Point --flutter at the Flutter command.',
      );
      return 1;
    }

    var exited = false;
    var interrupted = false;
    final exit = flutter.exitCode.whenComplete(() => exited = true);

    // Ctrl+C in a terminal reaches Flutter too — it shares the terminal — and
    // Flutter stops by itself, closing its debug service. An interrupt sent to
    // this process alone (an IDE, a script) is passed on if Flutter is still
    // running a moment later; whatever still runs after that is killed.
    final timers = <Timer>[];
    void stopFlutter({required Duration after}) {
      interrupted = true;
      timers
        ..add(Timer(after, () => exited || flutter.kill()))
        ..add(
          Timer(
            after + const Duration(seconds: 10),
            () => exited || flutter.kill(ProcessSignal.sigkill),
          ),
        );
    }

    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen(
        (_) => stopFlutter(after: const Duration(seconds: 2)),
      ),
      if (!Platform.isWindows)
        ProcessSignal.sigterm.watch().listen(
          (_) => stopFlutter(after: Duration.zero),
        ),
    ];

    unawaited(
      _waitForWebServer(webPort, () => exited).then((ready) async {
        if (!ready) return;
        _printBanner(
          proxy,
          title: 'dartway dev web — open the proxy, not Flutter\'s own port',
        );
        await _noteApiReachability(api);
      }),
    );

    final code = await exit;
    // A pending timer would keep this process alive after Flutter is gone.
    for (final timer in timers) {
      timer.cancel();
    }
    for (final subscription in signals) {
      await subscription.cancel();
    }
    await proxy.stop();
    return interrupted ? 0 : code;
  }

  /// The project from the working directory: its root, or its Flutter package.
  static ProjectLayout _detectLayout() {
    final here = Directory.current;
    try {
      return ProjectLayout.detect(here);
    } on StateError {
      if (p.basename(here.path).endsWith('_flutter')) {
        return ProjectLayout.detect(here.parent);
      }
      rethrow;
    }
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// Whether Flutter's web server came up before Flutter exited.
  static Future<bool> _waitForWebServer(
    int port,
    bool Function() exited,
  ) async {
    while (!exited()) {
      try {
        final socket = await Socket.connect(
          'localhost',
          port,
          timeout: const Duration(seconds: 1),
        );
        socket.destroy();
        return true;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }
}

/// The `flutter run` arguments of `dartway dev web`: the web server on
/// [webPort], compiled against the proxy's origin, then whatever the developer
/// added after `--`.
List<String> dwFlutterRunArguments({
  required int webPort,
  required Uri backendUrl,
  List<String> extra = const [],
}) => [
  'run',
  '-d',
  'web-server',
  '--web-port',
  '$webPort',
  '--web-hostname',
  'localhost',
  '--dart-define=DW_BACKEND_URL=$backendUrl',
  ...extra,
];

/// The Flutter command for a project: [override] when given, split on spaces
/// (`fvm flutter`); otherwise the FVM SDK linked into one of the [searched]
/// directories, `fvm flutter` where one of them pins a version in `.fvmrc`,
/// and `flutter` from the PATH.
(String, List<String>) flutterCommand({
  String? override,
  List<Directory> searched = const [],
}) {
  if (override != null && override.trim().isNotEmpty) {
    final parts = override.trim().split(RegExp(r'\s+'));
    return (parts.first, parts.skip(1).toList());
  }
  final binary = Platform.isWindows ? 'flutter.bat' : 'flutter';
  for (final directory in searched) {
    final linked = File(
      p.join(directory.path, '.fvm', 'flutter_sdk', 'bin', binary),
    );
    if (linked.existsSync()) return (linked.path, const []);
  }
  for (final directory in searched) {
    if (File(p.join(directory.path, '.fvmrc')).existsSync()) {
      return ('fvm', const ['flutter']);
    }
  }
  return ('flutter', const []);
}
