import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// The checksum of a migration's source file.
///
/// Computed over the source with the checksum literal itself emptied — a
/// file cannot contain its own hash — and with all whitespace removed, so
/// running `dart format` over a migration does not "change" it.
@internal
abstract final class DwChecksum {
  static final RegExp _declaration = RegExp(
    r"(String\s+get\s+checksum\s*=>\s*)'([^']*)'",
  );

  static final RegExp _id = RegExp(r"String\s+get\s+id\s*=>\s*'([^']+)'");

  static final RegExp _class = RegExp(
    r'class\s+(\w+)\s+extends\s+DwMigration\b',
  );

  static String of(String source) {
    final normalized = source
        .replaceAllMapped(_declaration, (match) => "${match[1]}''")
        .replaceAll(RegExp(r'\s+'), '');
    return sha256.convert(utf8.encode(normalized)).toString().substring(0, 32);
  }

  /// The checksum the file declares, or `null` when it declares none.
  static String? declared(String source) => _declaration.firstMatch(source)?[2];

  static String? idOf(String source) => _id.firstMatch(source)?[1];

  static String? classOf(String source) => _class.firstMatch(source)?[1];

  /// [source] with its declared checksum replaced by the computed one.
  static String seal(String source) {
    if (declared(source) == null) {
      throw FormatException('the migration declares no `String get checksum`');
    }
    final checksum = of(source);
    return source.replaceFirstMapped(
      _declaration,
      (match) => "${match[1]}'$checksum'",
    );
  }
}
