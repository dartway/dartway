import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../design_check/design_compare.dart';
import '../design_check/design_spec.dart';

class DesignCheckCommand extends Command<int> {
  DesignCheckCommand() {
    argParser
      ..addOption(
        'commit',
        mandatory: true,
        help: 'Publication commit containing the agreed Studio HTML.',
      )
      ..addMultiOption(
        'screen',
        help:
            'Repository path of a published screen HTML; repeat for every bound screen.',
      )
      ..addOption(
        'tests',
        defaultsTo: 'test/design_check',
        help: 'Widget-test directory containing the bound static states.',
      )
      ..addOption(
        'output',
        defaultsTo: 'build/design-check',
        help: 'Directory for captures and the combined report.',
      )
      ..addOption(
        'chrome',
        help:
            'Chrome/Chromium executable (otherwise CHROME_EXECUTABLE or PATH).',
      );
  }

  @override
  String get name => 'design-check';
  @override
  String get description =>
      'Compare Flutter static-state checks with Studio HTML at an agreed publication commit.';

  @override
  Future<int> run() async {
    if (argResults!.multiOption('screen').isEmpty) {
      usageException('At least one --screen is required.');
    }
    final root = Directory.current.path;
    final output = Directory(p.join(root, argResults!.option('output')!))
      ..createSync(recursive: true);
    final chrome =
        argResults!.option('chrome') ??
        Platform.environment['CHROME_EXECUTABLE'] ??
        _findChrome();
    if (chrome == null)
      throw StateError(
        'Chrome was not found; set CHROME_EXECUTABLE or pass --chrome.',
      );
    final captures = <_Capture>[];
    for (final screen in argResults!.multiOption('screen')) {
      final html = await _gitShow(root, argResults!.option('commit')!, screen);
      for (final viewport in _viewports(html)) {
        final id =
            '${p.basenameWithoutExtension(screen)}-${viewport.$1}x${viewport.$2}';
        final reference = await _captureReference(
          output,
          chrome,
          id,
          html,
          viewport,
        );
        captures.add(_Capture(screen, id, reference));
      }
    }
    final test = await Process.run(
      'flutter',
      [
        'test',
        argResults!.option('tests')!,
        '--dart-define=DW_DESIGN_CHECK_OUTPUT=${output.path}',
        '--dart-define=DW_DESIGN_CHECK_CASES=${captures.map((capture) => capture.id).join(',')}',
      ],
      workingDirectory: root,
      runInShell: true,
    );
    stdout.write(test.stdout);
    stderr.write(test.stderr);
    final findings = <Map<String, Object?>>[];
    if (test.exitCode == 0) {
      for (final capture in captures) {
        final appFile = File(p.join(output.path, 'app', '${capture.id}.json'));
        if (!appFile.existsSync()) {
          findings.add({
            'screen': capture.screen,
            'viewport': capture.id,
            'message': 'The widget test did not capture this case.',
          });
          continue;
        }
        final app = DesignSpec.decode(appFile.readAsStringSync());
        for (final finding in compareDesignSpecs(capture.reference, app)) {
          findings.add({
            'screen': capture.screen,
            'viewport': capture.id,
            ...finding.toJson(),
          });
        }
      }
    } else {
      findings.add({
        'message': 'Flutter design-check tests failed.',
        'exitCode': test.exitCode,
      });
    }
    final report = {
      'commit': argResults!.option('commit'),
      'findings': findings,
    };
    File(p.join(output.path, 'report.json')).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    final readable = StringBuffer(
      findings.isEmpty
          ? 'Design check passed.\n'
          : 'Design check found ${findings.length} difference(s):\n',
    );
    for (final finding in findings)
      readable.writeln(
        '- ${finding['viewport'] ?? ''} ${finding['node'] ?? ''}: ${finding['message']}',
      );
    File(
      p.join(output.path, 'report.txt'),
    ).writeAsStringSync(readable.toString());
    stdout.write(readable);
    return findings.isEmpty ? 0 : 1;
  }

  static String? _findChrome() {
    for (final name in ['google-chrome', 'chromium', 'chromium-browser']) {
      final result = Process.runSync('which', [name]);
      if (result.exitCode == 0) return (result.stdout as String).trim();
    }
    return null;
  }
}

Future<String> _gitShow(String root, String commit, String path) async {
  final result = await Process.run('git', [
    'show',
    '$commit:$path',
  ], workingDirectory: root);
  if (result.exitCode != 0)
    throw StateError('Cannot read $path at $commit: ${result.stderr}');
  return result.stdout as String;
}

List<(int, int)> _viewports(String html) {
  final values = <(int, int)>{};
  final pattern = RegExp(
    r'''<meta[^>]+name=["']dw-viewport["'][^>]+content=["'](\d+)x(\d+)["']''',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(html))
    values.add((int.parse(match.group(1)!), int.parse(match.group(2)!)));
  values.add((
    375,
    values.isEmpty ? 812 : values.first.$2,
  )); // narrow is mandatory
  return values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

Future<DesignSpec> _captureReference(
  Directory output,
  String chrome,
  String id,
  String html,
  (int, int) viewport,
) async {
  final referenceDir = Directory(p.join(output.path, 'reference'))
    ..createSync(recursive: true);
  const script =
      r'''<script>(async()=>{document.getAnimations().forEach(a=>a.finish());await document.fonts.ready;await Promise.all([...document.images].map(i=>i.complete?null:new Promise(r=>{i.onload=i.onerror=r})));const nodes=[...document.querySelectorAll('body *')].filter(e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return s.visibility!=='hidden'&&s.display!=='none'&&r.width&&r.height&&(e.children.length===0&&e.textContent.trim()||e.tagName==='IMG'||s.backgroundColor!=='rgba(0, 0, 0, 0)'||parseFloat(s.borderWidth)||s.boxShadow!=='none')}).map(e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return{path:e.id?'#'+e.id:e.tagName.toLowerCase(),rect:[r.x,r.y,r.width,r.height],text:e.children.length?'':e.textContent.trim(),fill:s.backgroundColor,stroke:s.borderColor,radius:parseFloat(s.borderRadius)||0,shadow:s.boxShadow==='none'?null:s.boxShadow,textStyle:{fontFamily:s.fontFamily,fontSize:parseFloat(s.fontSize),fontWeight:s.fontWeight,lineHeight:parseFloat(s.lineHeight)||null,color:s.color},overflow:r.right>innerWidth||r.left<0}});const o=document.createElement('pre');o.id='dw-design-spec';o.textContent=JSON.stringify({viewport:[innerWidth,innerHeight],nodes});document.body.append(o)})()</script>''';
  final source = html.replaceFirst(
    RegExp(r'</body>', caseSensitive: false),
    '$script</body>',
  );
  final file = File(p.join(referenceDir.path, '$id.html'))
    ..writeAsStringSync(source);
  final png = p.join(referenceDir.path, '$id.png');
  final result = await Process.run(chrome, [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--hide-scrollbars',
    '--window-size=${viewport.$1},${viewport.$2}',
    '--virtual-time-budget=3000',
    '--screenshot=$png',
    '--dump-dom',
    file.uri.toString(),
  ]);
  if (result.exitCode != 0)
    throw StateError('Browser capture failed for $id: ${result.stderr}');
  final match = RegExp(
    r'<pre id="dw-design-spec">(.*?)</pre>',
    dotAll: true,
  ).firstMatch(result.stdout as String);
  if (match == null)
    throw StateError('Published screen $id did not finish capture.');
  final encoded = match
      .group(1)!
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  final spec = DesignSpec.decode(encoded);
  File(p.join(referenceDir.path, '$id.json')).writeAsStringSync(encoded);
  return spec;
}

class _Capture {
  const _Capture(this.screen, this.id, this.reference);
  final String screen;
  final String id;
  final DesignSpec reference;
}
