import '../emit/source_text.dart';

/// One DTO class in the registry.
final class ProtocolEntry {
  const ProtocolEntry(this.name, this.importUri);

  final String name;

  /// The import that brings the class in, relative to `lib/generated/`.
  final String importUri;
}

/// Writes `lib/generated/dw_protocol.dart` of the shared package.
abstract final class ProtocolEmitter {
  static String emit({
    required String variable,
    required List<ProtocolEntry> entries,
  }) {
    final sorted = [...entries]..sort((a, b) => a.name.compareTo(b.name));
    final imports = {for (final entry in sorted) entry.importUri}.toList()
      ..sort();
    final out = StringBuffer()
      ..writeln(generatedHeader)
      ..writeln("import 'package:dartway_core/dartway_core.dart';");
    if (imports.isNotEmpty) out.writeln();
    for (final uri in imports) {
      out.writeln('import ${dartString(uri)};');
    }
    out
      ..writeln()
      ..write('final DwProtocol $variable = DwProtocol([');
    out.write(
      sorted
          .map(
            (entry) =>
                // The type argument is written out: inside the list literal
                // Dart would infer `DwDto` from the list, not the class from
                // the factory, and the protocol refuses such an entry.
                'DwDtoEntry<${entry.name}>(${dartString(entry.name)}, '
                '\$${entry.name}FromJson)',
          )
          .join(', '),
    );
    out.writeln('], include: DwProtocol.core);');
    return out.toString();
  }
}
