import 'dart:io';

class DwFlutterStat {
  DwFlutterStat(List<String> args);

  Future<void> run() async {
    await collectFeatureCodeStats();
  }

  Future<void> collectFeatureCodeStats() async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return;

    final rootDirs = libDir.listSync().whereType<Directory>().where((d) {
      final name = d.path.split(Platform.pathSeparator).last;
      return name.startsWith('app') ||
          name.startsWith('auth') ||
          name.startsWith('common') ||
          name.startsWith('admin');
    }).toList();

    final statsByDir = <String, _CodeStats>{};
    final totalStats = _CodeStats();

    for (final dir in rootDirs) {
      final name = dir.path.split(Platform.pathSeparator).last;
      final stats = _CodeStats();
      await _collectStatsRecursively(dir, stats);
      stats.finalize();
      statsByDir[name] = stats;

      totalStats.fileCount += stats.fileCount;
      totalStats.totalLines += stats.totalLines;
      totalStats.maxLines = stats.maxLines > totalStats.maxLines
          ? stats.maxLines
          : totalStats.maxLines;
      totalStats.minLines = stats.minLines < totalStats.minLines
          ? stats.minLines
          : totalStats.minLines;
    }

    for (final entry in statsByDir.entries) {
      print(entry.value.render('📁 ${entry.key}'));
    }

    totalStats.finalize();
    print(totalStats.render('🧮 Total (все фичи)'));
  }
}

class _CodeStats {
  int fileCount = 0;
  int totalLines = 0;
  int maxLines = 0;
  int minLines = 1 << 20;

  void addFile(String content) {
    final lines = '\n'.allMatches(content).length + 1;
    fileCount++;
    totalLines += lines;
    maxLines = lines > maxLines ? lines : maxLines;
    minLines = lines < minLines ? lines : minLines;
  }

  void finalize() {
    if (fileCount == 0) minLines = 0;
  }

  String render(String title) {
    if (fileCount == 0) return '$title: нет файлов\n';
    final avg = (totalLines / fileCount).toStringAsFixed(1);
    return '''
$title
  📄 Файлов:        $fileCount
  📏 Строк всего:   $totalLines
  📊 Среднее/файл:  $avg
  📈 Макс:          $maxLines
  📉 Мин:           $minLines
''';
  }
}

Future<void> _collectStatsRecursively(
  Directory dir,
  _CodeStats stats,
) async {
  final entities = dir.listSync(recursive: true);
  for (final entity in entities) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      stats.addFile(content);
    }
  }
}
