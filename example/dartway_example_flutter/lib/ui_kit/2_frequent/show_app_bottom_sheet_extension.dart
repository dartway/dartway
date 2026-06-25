part of '../ui_kit.dart';

extension ShowAppBottomSheetExtension on BuildContext {
  static showAppBottomSheetStatic(
    BuildContext context,
    Widget child,
  ) =>
      context.showAppBottomSheet(
        child: child,
        isWithDragHandle: true,
        isDismissible: true,
      );

  Future<T?> showAppBottomSheet<T>({
    required Widget child,
    bool isWithDragHandle = true,
    bool isDismissible = true,
  }) async {
    return await showModalBottomSheet<T>(
      context: this,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints.loose(
            Size(
              min(MediaQuery.of(sheetContext).size.width, 500),
              MediaQuery.of(sheetContext).size.height * 0.9 +
                  MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 +
                    MediaQuery.viewInsetsOf(sheetContext).bottom +
                    MediaQuery.paddingOf(sheetContext).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWithDragHandle)
                    const SizedBox(
                      width: 32,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(100),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Flexible(
                    fit: FlexFit.loose,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
