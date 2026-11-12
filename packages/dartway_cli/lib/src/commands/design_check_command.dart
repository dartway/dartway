import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../design_check/design_compare.dart';
import '../design_check/design_spec.dart';
import '../project_layout.dart';

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
      )
      ..addOption(
        'acceptance',
        help:
            'JSON file of accepted findings, each with case, node, message, and reason.',
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
    final projectRoot = findPackageProjectRoot(Directory.current);
    if (projectRoot == null) {
      throw StateError('design-check must run inside a DartWay project.');
    }
    final layout = ProjectLayout.detect(projectRoot);
    final root = layout.root.path;
    final flutterRoot = layout.flutterPackageDir.path;
    final output = Directory(p.join(flutterRoot, argResults!.option('output')!))
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
    final tree = await Directory.systemTemp.createTemp('dartway-design-check-');
    tree.deleteSync();
    try {
      await _materializeTree(root, argResults!.option('commit')!, tree.path);
      for (final screen in argResults!.multiOption('screen')) {
        final published = File(p.join(tree.path, screen));
        if (!published.existsSync()) {
          throw StateError(
            'Cannot read $screen at ${argResults!.option('commit')}.',
          );
        }
        final html = published.readAsStringSync();
        for (final viewport in _viewports(html)) {
          final screenId = p
              .withoutExtension(screen)
              .replaceAll(RegExp('[^A-Za-z0-9]+'), '-');
          final sizeClass = viewport.$3 == null ? '' : '-${viewport.$3}';
          final id = '$screenId$sizeClass-${viewport.$1}x${viewport.$2}';
          final reference = await captureDesignReferenceForTesting(
            output,
            chrome,
            id,
            published,
            (viewport.$1, viewport.$2),
          );
          captures.add(_Capture(screen, id, reference));
        }
      }
    } finally {
      await Process.run('git', [
        'worktree',
        'remove',
        '--force',
        tree.path,
      ], workingDirectory: root);
    }
    final test = await Process.run(_flutterExecutable(), [
      'test',
      argResults!.option('tests')!,
      '--dart-define=DW_DESIGN_CHECK_OUTPUT=${output.path}',
      '--dart-define=DW_DESIGN_CHECK_CASES=${captures.map((capture) => capture.id).join(',')}',
    ], workingDirectory: flutterRoot);
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
    final accepted = <Map<String, Object?>>[];
    final acceptancePath = argResults!.option('acceptance');
    if (acceptancePath != null) {
      final rules =
          (jsonDecode(
                    File(
                      p.join(flutterRoot, acceptancePath),
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map>()
              .map((value) => value.cast<String, Object?>())
              .toList();
      for (final finding in findings.toList()) {
        final rule = rules.where((rule) {
          final reason = rule['reason'];
          return reason is String &&
              reason.trim().isNotEmpty &&
              rule['case'] == finding['viewport'] &&
              rule['node'] == finding['node'] &&
              rule['message'] == finding['message'];
        }).firstOrNull;
        if (rule != null) {
          findings.remove(finding);
          accepted.add({...finding, 'reason': rule['reason']});
        }
      }
    }
    final report = {
      'commit': argResults!.option('commit'),
      'findings': findings,
      'accepted': accepted,
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

Future<void> _materializeTree(String root, String commit, String target) async {
  final result = await Process.run('git', [
    'worktree',
    'add',
    '--detach',
    target,
    commit,
  ], workingDirectory: root);
  if (result.exitCode != 0)
    throw StateError('Cannot materialize $commit: ${result.stderr}');
}

String _flutterExecutable() {
  if (!Platform.isWindows) return 'flutter';
  for (final directory in (Platform.environment['PATH'] ?? '').split(';')) {
    final candidate = File(p.join(directory, 'flutter.bat'));
    if (candidate.existsSync()) return candidate.path;
  }
  return 'flutter.bat';
}

List<(int, int, String?)> _viewports(String html) {
  final values = <(int, int, String?)>{};
  final pattern = RegExp(
    r'''<meta[^>]+name=["']dw-viewport["'][^>]+content=["'](?:(compact|medium|expanded):)?(\d+)x(\d+)["']''',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(html))
    values.add((
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(1),
    ));
  if (!values.any((value) => value.$1 == 375)) {
    values.add((
      375,
      values.isEmpty ? 812 : values.first.$2,
      'compact',
    )); // narrow is mandatory
  }
  return values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

Future<DesignSpec> captureDesignReferenceForTesting(
  Directory output,
  String chrome,
  String id,
  File published,
  (int, int) viewport,
) async {
  final referenceDir = Directory(p.join(output.path, 'reference'))
    ..createSync(recursive: true);
  const script = r'''<script>(async()=>{
await document.fonts.ready;
await Promise.all([...document.images].map(i=>i.complete?null:new Promise(r=>{i.onload=i.onerror=r})));
// Finishing an infinite Web Animation throws. Pause every animation first,
// and finish only those for which a finite end time exists. Repeat once for
// animations started by load handlers.
for(let pass=0;pass<2;pass++) { for(const a of document.getAnimations()) {
  try { const end=a.effect&&a.effect.getComputedTiming().endTime; if(Number.isFinite(end)) a.finish(); else a.pause(); } catch (_) { a.pause(); }
} await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))); }
const visible=e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return s.visibility!=='hidden'&&s.display!=='none'&&parseFloat(s.opacity)!==0&&r.width>0&&r.height>0&&r.right>0&&r.bottom>0&&r.left<innerWidth&&r.top<innerHeight};
const directText=e=>[...e.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join(' ').trim();
const painted=e=>{const s=getComputedStyle(e);return e===document.body||directText(e)||e.tagName==='IMG'||e.tagName==='SVG'||s.backgroundColor!=='rgba(0, 0, 0, 0)'&&s.backgroundColor!=='transparent'||parseFloat(s.borderTopWidth)||s.boxShadow!=='none'};
const nodes=[document.body,...document.querySelectorAll('body *')].filter(e=>visible(e)&&painted(e)).map(e=>{
 const s=getComputedStyle(e),r=e.getBoundingClientRect();
 const full=directText(e)||null;
 const range=document.createRange(); range.selectNodeContents(e);
 const textRect=full?range.getBoundingClientRect():null;
 const truncated=!!full&&(e.scrollWidth>e.clientWidth||e.scrollHeight>e.clientHeight||!!textRect&&(textRect.right>r.right+.5||textRect.bottom>r.bottom+.5))&&(s.textOverflow==='ellipsis'||s.overflow==='hidden');
 const border=parseFloat(s.borderTopWidth)||0;
 const transparent=c=>c==='rgba(0, 0, 0, 0)'||c==='transparent';
 const fill=e===document.body&&transparent(s.backgroundColor)?(transparent(getComputedStyle(document.documentElement).backgroundColor)?'rgb(255, 255, 255)':getComputedStyle(document.documentElement).backgroundColor):s.backgroundColor;
 return {path:e.tagName==='SVG'?'image':e.id?'#'+e.id:e.tagName.toLowerCase(),rect:e===document.body?[0,0,innerWidth,innerHeight]:[r.x,r.y,r.width,r.height],text:full,fill,stroke:s.borderTopStyle!=='none'&&border>0?s.borderTopColor:null,strokeWidth:border,radius:parseFloat(s.borderRadius)||0,shadow:s.boxShadow==='none'?null:s.boxShadow,textStyle:full?{fontFamily:s.fontFamily,fontSize:parseFloat(s.fontSize),fontWeight:s.fontWeight,lineHeight:parseFloat(s.lineHeight)||null,color:s.color}:{},overflow:r.right>innerWidth||r.left<0,truncated};
});
const o=document.createElement('pre');o.id='dw-design-spec';o.hidden=true;
const encoded=JSON.stringify({viewport:[innerWidth,innerHeight],nodes});
o.textContent=btoa(unescape(encodeURIComponent(encoded)));document.body.append(o)
})()</script>''';
  final source = published.readAsStringSync().replaceFirst(
    RegExp(r'</body>', caseSensitive: false),
    '$script</body>',
  );
  // Keep the instrumented copy beside the published screen so its relative
  // stylesheets, images and fonts resolve exactly as they do in the commit.
  final file = File(p.join(published.parent.path, '.dw-design-check-$id.html'))
    ..writeAsStringSync(source);
  final png = p.join(referenceDir.path, '$id.png');
  final common = [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--hide-scrollbars',
    '--window-size=${viewport.$1},${viewport.$2}',
    '--virtual-time-budget=3000',
  ];
  final screenshot = await Process.run(chrome, [
    ...common,
    '--screenshot=$png',
    file.uri.toString(),
  ]);
  if (screenshot.exitCode != 0) {
    throw StateError('Browser screenshot failed for $id: ${screenshot.stderr}');
  }
  final result = await Process.run(chrome, [
    ...common,
    '--dump-dom',
    file.uri.toString(),
  ]);
  file.deleteSync();
  if (result.exitCode != 0) {
    throw StateError('Browser DOM capture failed for $id: ${result.stderr}');
  }
  final match = RegExp(
    r'<pre[^>]*id="dw-design-spec"[^>]*>([^<]+)</pre>',
    dotAll: true,
  ).firstMatch(result.stdout as String);
  if (match == null)
    throw StateError('Published screen $id did not finish capture.');
  final encoded = utf8.decode(base64Decode(match.group(1)!));
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
