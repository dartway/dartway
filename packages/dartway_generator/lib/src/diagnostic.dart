import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

/// A problem in the project that stops generation.
///
/// Located problems print as `path:line:column: message` — the shape editors
/// and terminals turn into a link — because a generator error the author has
/// to hunt for is half an error message.
final class DwGenerationDiagnostic
    implements Comparable<DwGenerationDiagnostic> {
  const DwGenerationDiagnostic(
    this.message, {
    this.path,
    this.line,
    this.column,
  });

  /// A diagnostic pointing at the name of [element] (or at [offset] in its
  /// library file when given).
  factory DwGenerationDiagnostic.at(
    Element element,
    String message, {
    int? offset,
  }) {
    final fragment = element.firstFragment;
    final libraryFragment = fragment.libraryFragment!;
    final location = libraryFragment.lineInfo.getLocation(
      offset ?? fragment.nameOffset ?? fragment.offset,
    );
    return DwGenerationDiagnostic(
      message,
      path: libraryFragment.source.fullName,
      line: location.lineNumber,
      column: location.columnNumber,
    );
  }

  /// A diagnostic at [offset] of the file of [libraryFragment].
  factory DwGenerationDiagnostic.inFile(
    LibraryFragment libraryFragment,
    int offset,
    String message,
  ) {
    final location = libraryFragment.lineInfo.getLocation(offset);
    return DwGenerationDiagnostic(
      message,
      path: libraryFragment.source.fullName,
      line: location.lineNumber,
      column: location.columnNumber,
    );
  }

  final String message;
  final String? path;
  final int? line;
  final int? column;

  /// The printed form, with [path] relative to [root] when it lies inside it.
  String format(String root) {
    final path = this.path;
    if (path == null) return message;
    final shown = p.isWithin(root, path) ? p.relative(path, from: root) : path;
    return '$shown:$line:$column: $message';
  }

  @override
  int compareTo(DwGenerationDiagnostic other) {
    final byPath = (path ?? '').compareTo(other.path ?? '');
    if (byPath != 0) return byPath;
    final byLine = (line ?? 0).compareTo(other.line ?? 0);
    if (byLine != 0) return byLine;
    final byColumn = (column ?? 0).compareTo(other.column ?? 0);
    if (byColumn != 0) return byColumn;
    return message.compareTo(other.message);
  }

  @override
  bool operator ==(Object other) =>
      other is DwGenerationDiagnostic &&
      other.message == message &&
      other.path == path &&
      other.line == line &&
      other.column == column;

  @override
  int get hashCode => Object.hash(message, path, line, column);

  @override
  String toString() => format(p.current);
}
