import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// The bug this suite stands over was not a careless `try` block — it was two
/// methods of five where the block had never been written, on an endpoint whose
/// error handling has to be remembered once per method. Wrapping the two would
/// have left the same trap for the sixth method someone adds next year, so the
/// endpoint routes every method through one private `_guard`.
///
/// Nothing in the type system can insist on that: Serverpod fixes the shape of
/// an endpoint method, and a body written straight into it compiles perfectly
/// well. This test is the insistence. It reads the endpoint and fails on any
/// public method that answers with a [DwApiResponse] without delegating to the
/// guard — before the method reaches a project, rather than the first time its
/// list breaks in production.
void main() {
  late String source;

  /// Public methods declared on the endpoint that answer with a
  /// `Future<DwApiResponse<...>>` — every CRUD call the client can make.
  late List<RegExpMatch> declarations;

  setUpAll(() async {
    // Resolved through the package config rather than from the working
    // directory, so the suite reads the same file wherever it is run from.
    final uri = await Isolate.resolvePackageUri(
      Uri.parse(
        'package:dartway_serverpod_core_server/src/endpoints/dw_crud_endpoint.dart',
      ),
    );

    source = File.fromUri(uri!).readAsStringSync();
    declarations = RegExp(
      r'^  Future<DwApiResponse<.+?>>\s+([a-zA-Z]\w*)\(',
      multiLine: true,
    ).allMatches(source).toList();
  });

  String bodyOf(int index) => source.substring(
    declarations[index].start,
    index + 1 < declarations.length ? declarations[index + 1].start : null,
  );

  test('the scan sees the endpoint it is meant to guard', () {
    // A regex that matched nothing would let every assertion below pass
    // without reading a line of the endpoint.
    expect(
      declarations.map((m) => m.group(1)),
      containsAll(['getOne', 'getCount', 'getAll', 'saveModel', 'delete']),
    );
  });

  test('every CRUD method runs inside the guard', () {
    for (var i = 0; i < declarations.length; i++) {
      final name = declarations[i].group(1);

      expect(
        bodyOf(i),
        contains('_guard('),
        reason:
            'DwCrudEndpoint.$name does not delegate to _guard, so anything '
            'thrown under it escapes as a bare 500 that names no model and '
            'reaches no alert. Wrap the body: '
            "_guard('$name', className, () async { ... }).",
      );
    }
  });
}
