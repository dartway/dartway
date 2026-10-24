import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// The optional Studio publication, read from the project rather than inferred
/// from a directory that happens to exist. Paths stay inside Docker's context.
final class DwDesignResources {
  DwDesignResources._(this.flutterPackage, this.path);

  static DwDesignResources? read(Directory flutterPackage) {
    final file = File(
      p.join(flutterPackage.parent.path, '.dartway/design.json'),
    );
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map<String, dynamic> ||
        json.keys.any((key) => key != 'path')) {
      throw const FormatException('expected an object with an optional path');
    }
    final path = json.containsKey('path') ? json['path'] : 'dw_studio';
    if (path is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*$').hasMatch(path) ||
        {
          'assets',
          'lib',
          'test',
          'android',
          'ios',
          'web',
          'macos',
          'linux',
          'windows',
          'build',
        }.contains(p.posix.basename(path)) ||
        path.split('/').first == p.basename(flutterPackage.path)) {
      throw const FormatException(
        'path must name a design directory inside the project, using letters, digits, _, - and /',
      );
    }
    final result = DwDesignResources._(flutterPackage, path);
    if (result.source.existsSync() &&
        !p.isWithin(
          flutterPackage.parent.resolveSymbolicLinksSync(),
          result.source.resolveSymbolicLinksSync(),
        )) {
      throw const FormatException(
        'design directory resolves outside the project',
      );
    }
    return result;
  }

  final Directory flutterPackage;
  final String path;
  String get linkName => p.posix.basename(path);
  String get assetRoot => '$linkName/ui_kit/resources/';
  String get sourceRoot => '$path/ui_kit/resources/';
  Directory get source => Directory(p.join(flutterPackage.parent.path, path));
  Directory get resources => Directory(p.join(source.path, 'ui_kit/resources'));
  Link get link => Link(p.join(flutterPackage.path, linkName));

  String? get linkProblem {
    if (!resources.existsSync()) return '$sourceRoot does not exist';
    if (!link.existsSync()) {
      return '$linkName must be a symlink to ../$path; run dartway check --fix';
    }
    try {
      if (p.isAbsolute(link.targetSync()) ||
          link.resolveSymbolicLinksSync() !=
              source.resolveSymbolicLinksSync()) {
        return '$linkName must be a relative symlink to ../$path';
      }
    } on FileSystemException {
      return '$linkName is a dangling design symlink; expected ../$path';
    }
    return null;
  }

  /// Creates only an absent link. A copied directory or a wrong link belongs
  /// to its author: a check never deletes it to make a diagnostic disappear.
  String? createLink() {
    if (!resources.existsSync()) return null;
    if (FileSystemEntity.typeSync(link.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return null;
    }
    link.createSync(p.relative(source.path, from: flutterPackage.path));
    return '${p.basename(flutterPackage.path)}/$linkName -> ${link.targetSync()}';
  }

  /// The template's image uses /workspace and copies packages by name. Add
  /// the publication beside those packages, so the relative link survives.
  /// Custom Dockerfiles are diagnosed, never rewritten at a guessed location.
  List<String> prepareDocker() {
    final dockerfile = File(p.join(flutterPackage.path, 'Dockerfile'));
    if (!dockerfile.existsSync()) return const [];
    final copy = 'COPY $sourceRoot $sourceRoot';
    final anchor =
        'COPY ${p.basename(flutterPackage.path)}/ ${p.basename(flutterPackage.path)}/';
    final content = dockerfile.readAsStringSync();
    final changes = <String>[];
    if (!_copiesResources(dockerfile) && content.split('\n').contains(anchor)) {
      dockerfile.writeAsStringSync(
        content.replaceFirst(anchor, '$copy\n$anchor'),
      );
      changes.add('${p.basename(flutterPackage.path)}/Dockerfile: $copy');
    }
    final ignore = File(p.join(flutterPackage.parent.path, '.dockerignore'));
    if (ignore.existsSync()) {
      final lines = ignore.readAsLinesSync();
      final deny = lines.indexWhere((line) => line == '**' || line == '*');
      if (deny >= 0) {
        final parts = sourceRoot.split('/')..removeLast();
        final entries = [
          for (var i = 1; i <= parts.length; i++)
            '!${parts.take(i).join('/')}/',
          '!$sourceRoot**',
        ];
        final missing = entries
            .where((entry) => !lines.contains(entry))
            .toList();
        if (missing.isNotEmpty) {
          lines.insertAll(deny + 1, missing);
          ignore.writeAsStringSync('${lines.join('\n')}\n');
          changes.add('.dockerignore: admit $sourceRoot');
        }
      }
    }
    return changes;
  }

  List<String> dockerProblems() {
    final dockerfile = File(p.join(flutterPackage.path, 'Dockerfile'));
    if (!dockerfile.existsSync()) return const [];
    final ignore = File(p.join(flutterPackage.parent.path, '.dockerignore'));
    final patterns = <(bool, Glob)>[];
    if (ignore.existsSync()) {
      for (final raw in ignore.readAsLinesSync()) {
        var pattern = raw.trim();
        if (pattern.isEmpty || pattern.startsWith('#')) continue;
        final include = pattern.startsWith('!');
        if (include) pattern = pattern.substring(1);
        pattern = pattern.replaceAll(RegExp(r'^/|/$'), '');
        if (pattern.isEmpty || pattern == '.') continue;
        patterns.add((include, Glob(pattern, context: p.posix)));
      }
    }
    final excluded = resources.existsSync()
        ? resources
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .map(
                (file) => p
                    .relative(file.path, from: flutterPackage.parent.path)
                    .replaceAll(r'\', '/'),
              )
              .where((path) => _excluded(patterns, path))
              .toList()
        : <String>[];
    return [
      if (!_copiesResources(dockerfile))
        '${p.basename(flutterPackage.path)}/Dockerfile must copy $sourceRoot beside the Flutter package so the design link resolves; run dartway check --fix',
      if (excluded.isNotEmpty)
        '.dockerignore excludes ${excluded.first}; admit the resource (dartway check --fix handles the template allow-list)',
    ];
  }

  bool _copiesResources(File dockerfile) {
    var workdir = '/';
    final destinations = <String>{};
    final source = sourceRoot.substring(0, sourceRoot.length - 1);
    bool resolvesFrom(String directory) => destinations.contains(
      p.posix.normalize(p.posix.join(p.posix.dirname(directory), source)),
    );
    for (final raw in dockerfile.readAsLinesSync()) {
      final line = raw.trim();
      if (line.startsWith('FROM ')) {
        workdir = '/';
        destinations.clear();
      }
      if (line.startsWith('RUN ') && line.contains('flutter build'))
        return resolvesFrom(workdir);
      if (line.startsWith('WORKDIR ')) {
        workdir = p.posix.normalize(
          p.posix.join(workdir, line.substring(8).trim()),
        );
      }
      if (!line.startsWith('COPY ')) continue;
      final text = line.substring(5).trim();
      if (text.contains('--from=')) continue;
      List<String> args;
      try {
        if (text.startsWith('[')) {
          final json = jsonDecode(text);
          if (json is! List || json.any((value) => value is! String)) continue;
          args = json.cast<String>();
        } else {
          args = text
              .split(RegExp(r'\s+'))
              .where((a) => !a.startsWith('--'))
              .toList();
        }
      } on FormatException {
        continue;
      }
      if (args.length < 2) continue;
      final destination = p.posix.normalize(p.posix.join(workdir, args.last));
      for (final input in args.take(args.length - 1)) {
        final from = p.posix.normalize(input);
        if (from != '.' && from != source && !p.posix.isWithin(from, source)) {
          continue;
        }
        final relative = p.posix.relative(source, from: from);
        destinations.add(
          p.posix.normalize(p.posix.join(destination, relative)),
        );
      }
    }
    return resolvesFrom(workdir);
  }

  bool _excluded(List<(bool, Glob)> patterns, String file) {
    var excluded = false;
    final parts = file.split('/');
    final ancestors = [
      for (var i = 1; i <= parts.length; i++) parts.take(i).join('/'),
    ];
    for (final (include, glob) in patterns) {
      if (ancestors.any(
        (path) =>
            glob.matches(path) ||
            (!glob.pattern.contains('/') &&
                glob.matches(p.posix.basename(path))),
      )) {
        excluded = !include;
      }
    }
    return excluded;
  }

  /// Hash streams, not filenames: a renamed copy drifts just as readily.
  Future<List<String>> copiedAssets() async {
    if (!resources.existsSync()) return const [];
    final hashes = <Digest, List<String>>{};
    for (final file
        in resources
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()) {
      final digest = await sha256.bind(file.openRead()).first;
      hashes
          .putIfAbsent(digest, () => [])
          .add(
            '$assetRoot${p.relative(file.path, from: resources.path).replaceAll(r'\', '/')}',
          );
    }
    final assets = Directory(p.join(flutterPackage.path, 'assets'));
    if (!assets.existsSync()) return const [];
    final problems = <String>[];
    for (final file
        in assets
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()) {
      final keys = hashes[await sha256.bind(file.openRead()).first];
      if (keys == null) continue;
      keys.sort();
      problems.add(
        '${p.relative(file.path, from: flutterPackage.path)} copies Studio resource ${keys.join(', ')} — reference the design key in lib/ui_kit/assets/app_icon.dart and remove the copy',
      );
    }
    return problems..sort();
  }
}
