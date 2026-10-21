import 'package:dartway_core_server/dartway_core_server.dart';

/// Diagnostic requests are explicit and authenticated.
final systemInfoRoutes = [
  DwHttpRoute.get('/system-info', (ctx, request) async {
    final message = await ctx.http.get(
      Uri.parse('https://api.github.com/zen'),
      headers: {'user-agent': 'DartWay-seam-example'},
    );
    final git = await ctx.process.run('git', ['--version']);
    if (!message.isSuccess || git.exitCode != 0) {
      return DwHttpResponse.text('Diagnostics unavailable', status: 502);
    }
    return DwHttpResponse.json({
      'message': message.body.trim(),
      'gitVersion': git.stdout.trim(),
    });
  }, auth: DwRouteAuth.required),
];
