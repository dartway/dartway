part of '../../ui_kit.dart';

/// History anchored at the newest item on its first visible frame.
///
/// Items are supplied newest first. Set [isReady] only when their dependent
/// cards are ready too: the feature owns those reads, not the UI kit. There is
/// no post-frame scroll correction and no scroll offset restored on reopening.
class AppQuickSheetHistory extends HookWidget {
  const AppQuickSheetHistory({
    required this.isReady,
    required this.loading,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final bool isReady;
  final Widget loading;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController(keepScrollOffset: false);
    if (!isReady) return loading;
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.all(AppSpace.s16),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
