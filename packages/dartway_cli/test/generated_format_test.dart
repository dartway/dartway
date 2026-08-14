import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_generated_format.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The rule that keeps `dart format` from being an optional step after
/// `serverpod generate`. What it must get right is not the detection — the
/// formatter does that — but the reporting: this check compares against the
/// `dart_style` of whichever SDK ran it, so a developer on a different SDK can
/// see it go red for code they never wrote. A finding that only announces the
/// problem strands them; the fix command and the paths are the check.
///
/// Hence the formatter is stubbed here. The cases worth defending are the ones
/// the real `dart format` cannot be made to produce on demand: only one of the
/// two trees dirty (the fix must still name both), and a probe that could not
/// run at all (say nothing rather than guess).
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_generated_format');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// A project root with both packages present, each holding its generated
  /// tree. Returns the inspector, wired to a probe that answers from
  /// [unformatted]: a path segment mapped to the file names it reports dirty,
  /// anything unlisted coming back clean.
  DwGeneratedFormatInspector inspectorFor(
    Map<String, List<String>> unformatted,
  ) {
    Directory make(String package, String relative) {
      final packageDir = Directory(p.join(sandbox.path, package));
      Directory(p.join(packageDir.path, relative)).createSync(recursive: true);
      return packageDir;
    }

    return DwGeneratedFormatInspector(
      serverPackageDir: make(
        'my_app_server',
        DwGeneratedFormatInspector.serverGeneratedPath,
      ),
      clientPackageDir: make(
        'my_app_client',
        DwGeneratedFormatInspector.clientGeneratedPath,
      ),
      probe: (arguments) {
        final target = arguments.last;
        final dirty = unformatted[p.basename(target)] ?? const <String>[];
        if (dirty.isEmpty) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(
          0,
          1,
          dirty.map((f) => 'Changed ${p.join(target, f)}').join('\n'),
          '',
        );
      },
    );
  }

  test('generated code that matches dart format says nothing', () {
    final inspector = inspectorFor(const {});
    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
    expect(inspector.fixCommand, isNull);
  });

  test('each tree is named, with the files and the count', () {
    final inspector = inspectorFor(const {
      'generated': ['protocol.dart', 'endpoints.dart'],
      'protocol': ['client.dart'],
    })..run();

    expect(inspector.findings, hasLength(2));
    expect(
      inspector.findings.first,
      allOf(
        contains('my_app_server/lib/src/generated'),
        contains('2 files are not formatted'),
        contains('protocol.dart'),
        contains('endpoints.dart'),
      ),
    );
    expect(
      inspector.findings.last,
      allOf(
        contains('my_app_client/lib/src/protocol'),
        contains('1 file is not formatted'),
        contains('client.dart'),
      ),
    );
  });

  test('the fix command names both trees even when only one is dirty', () {
    // The case this rule exists for. One project kept the server tree
    // formatted and left the client raw; the next honest `dart format` put 33
    // unrelated files into an unrelated pull request. A fix that repairs only
    // what went red would reproduce exactly that.
    final inspector = inspectorFor(const {
      'protocol': ['client.dart'],
    })..run();

    expect(inspector.findings, hasLength(1));
    expect(
      inspector.fixCommand,
      'dart format my_app_server/lib/src/generated '
      'my_app_client/lib/src/protocol',
    );
  });

  test('a long list is truncated, and says how much it truncated', () {
    final inspector = inspectorFor({
      'generated': [for (var i = 0; i < 11; i++) 'model_$i.dart'],
    })..run();

    expect(
      inspector.findings.single,
      allOf(
        contains('11 files'),
        contains('model_0.dart'),
        contains('+8 more'),
      ),
    );
  });

  test('a formatter that could not run produces no finding', () {
    // `dart` missing from PATH, or a file it refused to parse. Neither is this
    // rule's business, and a finding invented from a failed probe is how a
    // check teaches people to ignore it.
    final inspector = DwGeneratedFormatInspector(
      serverPackageDir: Directory(p.join(sandbox.path, 'my_app_server'))
        ..createSync(recursive: true),
      probe: (_) => null,
    );
    Directory(
      p.join(
        sandbox.path,
        'my_app_server',
        DwGeneratedFormatInspector.serverGeneratedPath,
      ),
    ).createSync(recursive: true);

    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
  });

  test('a project with no generated tree yet is not a finding', () {
    final inspector = DwGeneratedFormatInspector(
      serverPackageDir: Directory(p.join(sandbox.path, 'my_app_server'))
        ..createSync(recursive: true),
      clientPackageDir: Directory(p.join(sandbox.path, 'my_app_client'))
        ..createSync(recursive: true),
      probe: (_) => fail('the formatter must not be run on a missing tree'),
    );

    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
  });

  test('a Flutter package checked on its own has nothing to say', () {
    final inspector = DwGeneratedFormatInspector(
      probe: (_) => fail('there is no server or client package here'),
    );

    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
  });

  test('--type and --level narrow to this check the way the others do', () {
    final serverDir = Directory(p.join(sandbox.path, 'my_app_server'));
    Directory(
      p.join(serverDir.path, DwGeneratedFormatInspector.serverGeneratedPath),
    ).createSync(recursive: true);

    for (final (filterType, filterSeverity)
        in <(DwCheckType?, DwCheckSeverity?)>[
          (DwCheckType.invalidTopLevelLayout, null),
          (null, DwCheckSeverity.error),
        ]) {
      final inspector = DwGeneratedFormatInspector(
        serverPackageDir: serverDir,
        filterType: filterType,
        filterSeverity: filterSeverity,
        probe: (_) => fail('a filtered-out check must not run the formatter'),
      );
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
    }

    // …and the check's own name and severity do select it.
    final selected = DwGeneratedFormatInspector(
      serverPackageDir: serverDir,
      filterType: DwCheckType.generatedCodeUnformatted,
      filterSeverity: DwCheckSeverity.warning,
      probe: (arguments) =>
          ProcessResult(0, 1, 'Changed ${arguments.last}/protocol.dart', ''),
    )..run();
    expect(selected.findings, hasLength(1));
  });

  test('a warning does not fail the check', () {
    // Deliberate: the comparison is against the SDK that ran the check, so an
    // error here would block a team split across SDK versions on something
    // none of them did wrong. See DwCheckType.generatedCodeUnformatted.
    expect(
      DwCheckType.generatedCodeUnformatted.severity,
      DwCheckSeverity.warning,
    );
    expect(
      inspectorFor(const {
        'generated': ['protocol.dart'],
      }).run(),
      0,
    );
  });
}
