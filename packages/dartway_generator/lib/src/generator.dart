import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/formatter_options.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'analysis/framework.dart';
import 'analysis/library_names.dart';
import 'diagnostic.dart';
import 'dto/dto_emitter.dart';
import 'dto/dto_model.dart';
import 'dto/dto_reader.dart';
import 'dto/protocol_emitter.dart';
import 'emit/output.dart';
import 'emit/source_text.dart';
import 'entity/entity_emitter.dart';
import 'entity/entity_model.dart';
import 'entity/entity_reader.dart';
import 'entity/schema_emitter.dart';
import 'project.dart';
import 'sdk.dart';

/// The outcome of one generator run.
final class DwGenerationReport {
  const DwGenerationReport({
    required this.root,
    required this.written,
    required this.unchanged,
    required this.removed,
    required this.diagnostics,
    required this.elapsed,
    required this.check,
    this.skipped = const [],
  });

  final String root;

  /// Packages not scanned: a `*_flutter` package without a resolved package
  /// config, left out so the contract and the server still generate. Their
  /// generated parts, if any, were neither written nor checked.
  final List<String> skipped;

  /// Files whose content changed (in check mode: would change).
  final List<String> written;
  final List<String> unchanged;

  /// Stale generated parts (in check mode: that would be removed).
  final List<String> removed;

  /// Problems that stopped generation. When not empty, nothing was written.
  final List<DwGenerationDiagnostic> diagnostics;
  final Duration elapsed;
  final bool check;

  bool get hasErrors => diagnostics.isNotEmpty;

  /// Whether the generated files on disk are exactly what the sources produce.
  bool get isUpToDate => !hasErrors && written.isEmpty && removed.isEmpty;

  String get summary {
    final seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(2);
    if (hasErrors) {
      final count = diagnostics.length;
      return 'dartway generate: $count error${count == 1 ? '' : 's'}, '
          'nothing written ($seconds s)';
    }
    if (check) {
      return 'dartway generate --check: ${written.length} out of date, '
          '${removed.length} stale, ${unchanged.length} up to date '
          '($seconds s)';
    }
    final notScanned = skipped.isEmpty
        ? ''
        : '; not scanned: ${skipped.join(', ')} — run `dart pub get` there';
    return 'dartway generate: ${written.length} written, '
        '${unchanged.length} unchanged, ${removed.length} removed '
        '($seconds s)$notScanned';
  }
}

/// Generates the code of a DartWay project: DTO parts and the protocol
/// registry in the shared package, entity parts and the schema in the server
/// package.
///
/// A run either writes everything or nothing: the first problem does not stop
/// the analysis (every problem is reported at once), but any problem stops the
/// writing, so the project is never left half-generated.
abstract final class DwCodeGenerator {
  /// Runs over the project at [projectRoot] — a directory holding the
  /// `*_shared` / `*_server` / `*_flutter` packages, or one such package.
  ///
  /// [sdkPath] overrides the Dart SDK the analyzer reads; by default it is
  /// found from the running `dart` or `PATH`. With [check] nothing is written
  /// and the report tells what would change.
  static Future<DwGenerationReport> run(
    String projectRoot, {
    String? sdkPath,
    bool check = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    // Resolved, because the analyzer reports resolved paths and every path
    // this run compares or prints must agree with them.
    var root = p.normalize(p.absolute(projectRoot));
    if (Directory(root).existsSync()) {
      root = Directory(root).resolveSymbolicLinksSync();
    }
    final diagnostics = <DwGenerationDiagnostic>[];
    final skipped = <String>[];

    DwGenerationReport finish({OutputPlan? plan}) {
      diagnostics.sort();
      return DwGenerationReport(
        root: root,
        written: plan?.written ?? const [],
        unchanged: plan?.unchanged ?? const [],
        removed: plan?.removed ?? const [],
        diagnostics: List.unmodifiable(diagnostics),
        elapsed: stopwatch.elapsed,
        check: check,
        skipped: List.unmodifiable(skipped),
      );
    }

    // `--check` answers whether everything is up to date, which it cannot
    // for a package it did not read: there an unresolved app stays an error.
    final packages = detectPackages(
      root,
      diagnostics,
      skipped: check ? null : skipped,
    );
    if (diagnostics.isNotEmpty) return finish();

    final collection = AnalysisContextCollection(
      includedPaths: [for (final package in packages) package.root],
      sdkPath: sdkPath ?? findDartSdk(),
    );
    try {
      final run = _Run(diagnostics);
      for (final package in packages) {
        await run.scanPackage(package, collection.contextFor(package.root));
      }
      final files = run.emit();
      if (diagnostics.isNotEmpty) return finish();
      final plan = planOutput(files, packages);
      if (!check) plan.apply();
      return finish(plan: plan);
    } finally {
      await collection.dispose();
    }
  }
}

/// A library with a generated part.
final class _Library {
  _Library({required this.package, required this.element, required this.path});

  final DwProjectPackage package;
  final LibraryElement element;
  final String path;

  /// Generated sections in declaration order, keyed by class element.
  final List<(ClassElement, DtoClass?, EntityClass?)> classes = [];

  String get partName => '${p.basenameWithoutExtension(path)}.dw.dart';

  String get partPath => p.join(p.dirname(path), partName);
}

final class _Run {
  _Run(this.diagnostics);

  final List<DwGenerationDiagnostic> diagnostics;
  final List<_Library> libraries = [];
  final Map<DwProjectPackage, AnalysisContext> contexts = {};

  Future<void> scanPackage(
    DwProjectPackage package,
    AnalysisContext context,
  ) async {
    contexts[package] = context;
    final lib = Directory(package.lib);
    if (!lib.existsSync()) return;
    final paths =
        [
            for (final entity in lib.listSync(recursive: true))
              if (entity is File &&
                  entity.path.endsWith('.dart') &&
                  !entity.path.endsWith('.dw.dart'))
                p.normalize(entity.path),
          ]
          ..removeWhere((path) => p.split(path).contains('.dart_tool'))
          ..sort();

    final session = context.currentSession;
    for (final path in paths) {
      // Resolving a library is the expensive step; a library that neither
      // declares a generated part nor uses a generated mixin has nothing to
      // generate and nothing to report, so its text decides whether to pay.
      final text = File(path).readAsStringSync();
      if (!text.contains('.dw.dart') && !text.contains(r'_$')) continue;

      final uri = session.uriConverter.pathToUri(path);
      if (uri == null) continue;
      final result = await session.getLibraryByUri(uri.toString());
      if (result is! LibraryElementResult) continue;
      final element = result.element;
      if (p.normalize(element.firstFragment.source.fullName) != path) continue;
      _scanLibrary(_Library(package: package, element: element, path: path));
    }
  }

  void _scanLibrary(_Library library) {
    final element = library.element;
    final fragment = element.firstFragment;
    final session = element.session;

    var declaresPart = false;
    var misnamedPart = false;
    for (final include in fragment.partIncludes) {
      final uri = include.uri;
      if (uri is! DirectiveUriWithRelativeUriString) continue;
      final written = uri.relativeUriString;
      if (!written.endsWith('.dw.dart')) continue;
      if (written != library.partName || declaresPart) {
        diagnostics.add(
          DwGenerationDiagnostic.inFile(
            fragment,
            include.partKeywordOffset,
            declaresPart
                ? 'the generated part is declared twice'
                : 'the generated part of `${p.basename(library.path)}` must '
                      "be `part '${library.partName}';`, not `part '$written';`",
          ),
        );
        misnamedPart = true;
        continue;
      }
      declaresPart = true;
    }

    final declarations = <String, ClassDeclaration>{};
    final parsedFiles = <String>{};
    final names = LibraryNames(element);
    final dtoReader = DtoReader(names, diagnostics);
    final entityReader = EntityReader(names, diagnostics);
    ClassElement? firstGenerated;

    for (final classElement in element.classes) {
      final dtoKind = DwFrameworkTypes.dtoKindOf(classElement);
      final isEntity = DwFrameworkTypes.isEntity(classElement);
      if (dtoKind == null && !isEntity) continue;
      if (DwFrameworkTypes.isFramework(classElement)) continue;
      if (classElement.isAbstract || classElement.isSealed) continue;
      final name = classElement.name!;

      final file = classElement.firstFragment.libraryFragment.source.fullName;
      if (parsedFiles.add(file)) {
        final parsed = session.getParsedUnit(file);
        if (parsed is ParsedUnitResult) {
          for (final declaration
              in parsed.unit.declarations.whereType<ClassDeclaration>()) {
            declarations[declaration.namePart.typeName.lexeme] = declaration;
          }
        }
      }
      final declaration = declarations[name];
      if (declaration == null) continue;

      firstGenerated ??= classElement;
      if (name.startsWith('_')) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            classElement,
            '`$name` is private, but the generated '
            '${isEntity ? 'schema' : 'protocol registry'} lives in another '
            'library and must name it; make the class public',
          ),
        );
        continue;
      }
      final mixin = '_\$$name';
      final hasMixin =
          declaration.withClause?.mixinTypes.any(
            (type) => type.importPrefix == null && type.name.lexeme == mixin,
          ) ??
          false;
      if (!hasMixin) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            classElement,
            '`$name` must mix in its generated code: declare it as '
            '`class $name extends … with $mixin`',
          ),
        );
        continue;
      }

      if (isEntity) {
        final entity = entityReader.read(classElement, declaration);
        if (entity != null) library.classes.add((classElement, null, entity));
      } else {
        final dto = dtoReader.read(classElement, dtoKind!, declaration);
        if (dto != null) library.classes.add((classElement, dto, null));
      }
    }

    if (firstGenerated != null && !declaresPart && !misnamedPart) {
      diagnostics.add(
        DwGenerationDiagnostic.at(
          firstGenerated,
          '`${p.basename(library.path)}` declares generated classes but not '
          "their part: add `part '${library.partName}';` after the imports",
        ),
      );
      return;
    }
    if (declaresPart && !misnamedPart) libraries.add(library);
  }

  /// DTO names already reported as colliding; not reported a second time as
  /// a registry ambiguity.
  final Set<String> _collidingNames = {};

  List<GeneratedFile> emit() {
    _checkWireNames();
    _checkEntities();
    final files = <GeneratedFile>[];
    for (final library in libraries) {
      files.add(_emitPart(library));
    }
    for (final package in contexts.keys) {
      switch (package.role) {
        // A package that cannot import the framework package would get a
        // registry or schema that does not compile; without DTOs or entities
        // it simply has none.
        case DwPackageRole.shared
            when _resolves(package, 'dartway_core_shared'):
          files.add(_emitProtocol(package));
        case DwPackageRole.server when _resolves(package, 'dartway_orm'):
          files.add(_emitSchema(package));
        default:
          break;
      }
    }
    return files;
  }

  /// The package a server package's generated code imports the ORM through.
  /// A project depends on `dartway_core_server`, which re-exports the ORM
  /// (D-030); importing `dartway_orm` there would reach into a dependency the
  /// package does not declare (`depend_on_referenced_packages`). So the
  /// declaration decides, not resolution — the server package brings the ORM
  /// into every package config either way. Only a package that declares the
  /// ORM alone (the ORM's own fixtures) gets `dartway_orm`.
  String _serverFrameworkPackage(DwProjectPackage package) =>
      _serverFrameworkPackages.putIfAbsent(package, () {
        const server = 'dartway_core_server';
        return _declares(package, server) && _resolves(package, server)
            ? server
            : 'dartway_orm';
      });

  final Map<DwProjectPackage, String> _serverFrameworkPackages = {};

  static bool _declares(DwProjectPackage package, String dependency) {
    try {
      final pubspec = loadYaml(
        File(p.join(package.root, 'pubspec.yaml')).readAsStringSync(),
      );
      return pubspec is YamlMap &&
          pubspec['dependencies'] is YamlMap &&
          (pubspec['dependencies'] as YamlMap).containsKey(dependency);
    } on Exception {
      // The package was detected from this very file; one that no longer
      // reads keeps the ORM import, and analysis reports the rest.
      return false;
    }
  }

  bool _resolves(DwProjectPackage package, String dependency) =>
      contexts[package]!.currentSession.uriConverter.uriToPath(
        Uri.parse('package:$dependency/$dependency.dart'),
      ) !=
      null;

  /// Row classes feed one schema and one `DwDatabaseHandle` extension, so their
  /// table names, class names, index names and repository getters must not
  /// collide.
  void _checkEntities() {
    final entities = <EntityClass>[];
    for (final library in libraries) {
      for (final (element, _, entity) in library.classes) {
        if (entity == null) continue;
        if (library.package.role != DwPackageRole.server) {
          diagnostics.add(
            DwGenerationDiagnostic.at(
              element,
              'row class `${entity.name}` is declared in '
              '`${library.package.name}`; row classes belong in the *_server '
              'package, whose schema lists them',
            ),
          );
          continue;
        }
        entities.add(entity);
      }
    }

    void unique(String what, Iterable<(String, EntityClass)> keys) {
      final byKey = <String, List<EntityClass>>{};
      for (final (key, entity) in keys) {
        (byKey[key] ??= []).add(entity);
      }
      for (final MapEntry(:key, value: owners) in byKey.entries) {
        if (owners.length < 2) continue;
        for (final owner in owners) {
          final others = owners
              .where((other) => other != owner)
              .map((other) => _locationOf(other.element))
              .join(', ');
          diagnostics.add(
            DwGenerationDiagnostic.at(
              owner.element,
              '$what `$key` of row class `${owner.name}` is also used at '
              '$others',
            ),
          );
        }
      }
    }

    unique('table name', [for (final e in entities) (e.tableName, e)]);
    unique('class name', [for (final e in entities) (e.name, e)]);
    unique('repository getter', [
      for (final e in entities) (e.repositoryGetter, e),
    ]);
    unique('index name', [
      for (final e in entities)
        for (final index in e.indexes) (index.name, e),
    ]);

    for (final entity in entities) {
      final handleClass = entity.element.library.firstFragment.scope
          .lookup('DwDatabaseHandle')
          .getter;
      if (handleClass is! InterfaceElement) continue;
      final members = {
        for (final type in [
          handleClass.thisType,
          ...handleClass.allSupertypes,
        ]) ...[
          for (final field in type.element.fields) field.name,
          for (final method in type.element.methods) method.name,
        ],
      };
      if (members.contains(entity.repositoryGetter)) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            entity.element,
            'the repository getter of row class `${entity.name}` would be '
            '`${entity.repositoryGetter}`, which DwDatabaseHandle already declares; rename '
            'the class',
          ),
        );
      }
    }
  }

  /// Framework names a generated part uses without a prefix, by the package
  /// that must be imported for them.
  static const _frameworkNames = {
    'DwJsonCodec': 'dartway_core_shared',
    'DwFieldPatch': 'dartway_core_shared',
    'dwListEquals': 'dartway_core_shared',
    'dwMapEquals': 'dartway_core_shared',
    'DwTableColumn': 'dartway_orm',
    'DwColumnType': 'dartway_orm',
    'DwEnumType': 'dartway_orm',
    'DwEnumListType': 'dartway_orm',
    'DwJsonListType': 'dartway_orm',
    'DwJsonMapType': 'dartway_orm',
    'DwTableDef': 'dartway_orm',
    'DwResultRow': 'dartway_orm',
    'DwForeignKey': 'dartway_orm',
    'DwOnDelete': 'dartway_orm',
    'DwDefaultValue': 'dartway_orm',
    'DwIndexSchema': 'dartway_orm',
  };

  /// A part has no imports of its own: every framework name it writes must be
  /// visible, unprefixed, in its library.
  void _checkFrameworkNames(_Library library, String generated) {
    final scope = library.element.firstFragment.scope;
    final hasEntities = library.classes.any((entry) => entry.$3 != null);
    final missing = <String>[];
    final packages = <String>{};
    for (final MapEntry(key: name, value: package) in _frameworkNames.entries) {
      if (!RegExp('\\b$name\\b').hasMatch(generated)) continue;
      final visible = scope.lookup(name).getter;
      if (visible != null && DwFrameworkTypes.isFramework(visible)) continue;
      missing.add('`$name`');
      // The server package (through dartway_orm) re-exports what row class
      // parts need from dartway_core_shared.
      packages.add(
        hasEntities ? _serverFrameworkPackage(library.package) : package,
      );
    }
    if (missing.isEmpty) return;
    final imports = [
      for (final package in packages.toList()..sort())
        "`import 'package:$package/$package.dart';`",
    ];
    diagnostics.add(
      DwGenerationDiagnostic.at(
        library.classes.first.$1,
        'the generated part uses ${missing.join(', ')}, which '
        '`${p.basename(library.path)}` does not import without a prefix; add '
        '${imports.join(' and ')}',
      ),
    );
  }

  GeneratedFile _emitPart(_Library library) {
    final sections = <String>[
      for (final (_, dto, entity) in library.classes)
        if (dto != null) DtoEmitter.emit(dto) else EntityEmitter.emit(entity!),
    ];
    if (sections.isNotEmpty) _checkFrameworkNames(library, sections.join());
    final source = StringBuffer()
      ..writeln(generatedHeader)
      ..writeln("part of ${dartString(p.basename(library.path))};");
    for (final section in sections) {
      source
        ..writeln()
        ..writeln(section);
    }
    return GeneratedFile(
      library.partPath,
      formatDart(
        source.toString(),
        languageVersion: library.element.languageVersion.effective,
        options: _formatterOptions(library.package),
        path: library.partPath,
      ),
    );
  }

  /// Wire names are class names, and two classes under one name would make the
  /// protocol refuse to start — so the collision is reported here, at both
  /// declarations, including collisions with the framework's own DTOs.
  void _checkWireNames() {
    final byName = <String, List<ClassElement>>{};
    for (final library in libraries) {
      for (final (element, dto, _) in library.classes) {
        if (dto != null) (byName[dto.name] ??= []).add(element);
      }
    }
    final coreNames = _coreDtoNames();
    for (final MapEntry(key: name, value: elements) in byName.entries) {
      if (coreNames.contains(name)) {
        _collidingNames.add(name);
        for (final element in elements) {
          diagnostics.add(
            DwGenerationDiagnostic.at(
              element,
              'DTO name `$name` is already taken by a dartway_core_shared DTO; wire '
              'names must be unique, rename the class',
            ),
          );
        }
      }
      if (elements.length < 2) continue;
      _collidingNames.add(name);
      for (final element in elements) {
        final others = elements
            .where((other) => other != element)
            .map(_locationOf)
            .join(', ');
        diagnostics.add(
          DwGenerationDiagnostic.at(
            element,
            'DTO name `$name` is declared more than once (also at $others); '
            'wire names must be unique across the project',
          ),
        );
      }
    }
  }

  Set<String> _coreDtoNames() {
    for (final library in libraries) {
      final core = _coreLibrary(library.element);
      if (core == null) continue;
      return {
        for (final element in core.exportNamespace.definedNames2.values)
          if (element is ClassElement &&
              !element.isAbstract &&
              DwFrameworkTypes.dtoKindOf(element) != null)
            element.name!,
      };
    }
    return const {};
  }

  static LibraryElement? _coreLibrary(LibraryElement from) {
    for (final imported in from.firstFragment.importedLibraries) {
      if (imported.uri.toString() ==
          'package:dartway_core_shared/dartway_core_shared.dart') {
        return imported;
      }
    }
    for (final imported in from.firstFragment.importedLibraries) {
      for (final exported in imported.exportedLibraries) {
        if (exported.uri.toString() ==
            'package:dartway_core_shared/dartway_core_shared.dart') {
          return exported;
        }
      }
    }
    return null;
  }

  String _locationOf(Element element) {
    final diagnostic = DwGenerationDiagnostic.at(element, '');
    return '${p.basename(diagnostic.path!)}:${diagnostic.line}:'
        '${diagnostic.column}';
  }

  GeneratedFile _emitProtocol(DwProjectPackage package) {
    final entries = <ProtocolEntry>[];
    final registered = <(ClassElement, _Library)>[];
    for (final library in libraries) {
      if (library.package != package) continue;
      final relative = p.relative(library.path, from: package.lib);
      final importUri = p.url.relative(
        p.split(relative).join('/'),
        from: 'generated',
      );
      for (final (element, dto, _) in library.classes) {
        if (dto == null) continue;
        entries.add(ProtocolEntry(dto.name, importUri));
        registered.add((element, library));
      }
    }

    // The registry imports every DTO library unprefixed; a name any of them
    // (or dartway_core_shared) also exports would be ambiguous there.
    final imported = <LibraryElement>{
      for (final (_, library) in registered) library.element,
    };
    for (final (element, library) in registered) {
      if (_collidingNames.contains(element.name)) continue;
      final core = _coreLibrary(library.element);
      for (final other in [...imported, ?core]) {
        if (other == library.element) continue;
        for (final name in [element.name!, '\$${element.name}FromJson']) {
          final clash = other.exportNamespace.get2(name);
          if (clash == null || clash == element) continue;
          if (clash is TopLevelFunctionElement &&
              clash.library == element.library) {
            continue;
          }
          diagnostics.add(
            DwGenerationDiagnostic.at(
              element,
              '`$name` is also exported by `${other.uri}`, so the generated '
              'protocol registry cannot name it unambiguously; rename one of '
              'them',
            ),
          );
        }
      }
    }

    final path = p.join(package.lib, 'generated', 'dw_protocol.dart');
    return GeneratedFile(
      path,
      formatDart(
        ProtocolEmitter.emit(
          variable: '${camelCase(package.baseName)}Protocol',
          entries: entries,
        ),
        languageVersion: package.languageVersion,
        options: _formatterOptions(package),
        path: path,
      ),
    );
  }

  GeneratedFile _emitSchema(DwProjectPackage package) {
    final entities = <EntityClass>[
      for (final library in libraries)
        if (library.package == package)
          for (final (_, _, entity) in library.classes) ?entity,
    ];
    final path = p.join(package.lib, 'generated', 'dw_schema.dart');
    final importUris = <String>{
      for (final library in libraries)
        if (library.package == package &&
            library.classes.any((entry) => entry.$3 != null))
          p.url.relative(
            p.split(p.relative(library.path, from: package.lib)).join('/'),
            from: 'generated',
          ),
    };
    return GeneratedFile(
      path,
      formatDart(
        SchemaEmitter.emit(
          baseName: package.baseName,
          entities: entities,
          imports: importUris.toList()..sort(),
          frameworkPackage: _serverFrameworkPackage(package),
        ),
        languageVersion: package.languageVersion,
        options: _formatterOptions(package),
        path: path,
      ),
    );
  }

  FormatterOptions _formatterOptions(DwProjectPackage package) {
    final context = contexts[package]!;
    final pubspec = context.currentSession.resourceProvider.getFile(
      p.join(package.root, 'pubspec.yaml'),
    );
    return context.getAnalysisOptionsForFile(pubspec).formatterOptions;
  }
}
