import 'dart:io';

/// Code-size statistics over the feature folders of a Flutter package
/// (`lib/app*`, `lib/auth*`, `lib/common*`, `lib/admin*`).
class DwFlutterStat {
  DwFlutterStat({required this.packageDir});

  final Directory packageDir;

  Future<void> run() async {
    final libDir =
        Directory('${packageDir.path}${Platform.pathSeparator}lib');
    if (!libDir.existsSync()) {
      print('❌ No lib/ folder in ${packageDir.path}');
      return;
    }

    final rootDirs = libDir.listSync().whereType<Directory>().where((d) {
      final name = d.path.split(Platform.pathSeparator).last;
      return name.startsWith('app') ||
          name.startsWith('auth') ||
          name.startsWith('common') ||
          name.startsWith('admin');
    }).toList();

    final totalStats = _CodeStats();

    for (final dir in rootDirs) {
      final name = dir.path.split(Platform.pathSeparator).last;
      final stats = _CodeStats();
      await _collectStatsRecursively(dir, stats);
      stats.finalize();
      print(stats.render('📁 $name'));

      totalStats.fileCount += stats.fileCount;
      totalStats.totalLines += stats.totalLines;
      totalStats.maxLines = stats.maxLines > totalStats.maxLines
          ? stats.maxLines
          : totalStats.maxLines;
      totalStats.minLines = stats.minLines < totalStats.minLines
          ? stats.minLines
          : totalStats.minLines;
    }

    totalStats.finalize();
    print(totalStats.render('🧮 Total (all features)'));
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
    if (fileCount == 0) return '$title: no files\n';
    final avg = (totalLines / fileCount).toStringAsFixed(1);
    return '''
$title
  📄 Files:          $fileCount
  📏 Total lines:    $totalLines
  📊 Avg per file:   $avg
  📈 Max:            $maxLines
  📉 Min:            $minLines
''';
  }
}

Future<void> _collectStatsRecursively(
  Directory dir,
  _CodeStats stats,
) async {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      stats.addFile(await entity.readAsString());
    }
  }
}
