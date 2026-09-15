import 'dart:io';

/// Whether this run refreshes the goldens: `DW_UPDATE_GOLDENS=1`.
bool get goldenUpdateRequested =>
    Platform.environment['DW_UPDATE_GOLDENS'] == '1';

/// Writes a golden file, relative to the package the tests run in.
void writeGolden(String path, String content) {
  final file = File(path);
  if (!file.parent.existsSync()) {
    throw StateError(
      'No ${file.parent.path} here: run the tests from the package root.',
    );
  }
  file.writeAsStringSync(content);
}
