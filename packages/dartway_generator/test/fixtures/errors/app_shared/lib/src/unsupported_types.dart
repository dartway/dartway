import 'dart:typed_data';

import 'package:dartway_core/dartway_core.dart';

part 'unsupported_types.dw.dart';

abstract class AbstractView extends DwDataObject {
  const AbstractView();
}

final class Unsupported extends DwActionCommand<void> with _$Unsupported {
  const Unsupported({
    required this.set,
    required this.nested,
    required this.intKeys,
    this.nullablePatch,
    this.patchOfNullable = const DwFieldPatch.keep(),
    this.patchOfList = const DwFieldPatch.keep(),
    required this.bytesList,
    required this.abstractView,
    required this.number,
    required this.object,
  });

  final Set<int> set;
  final List<List<int>> nested;
  final Map<int, String> intKeys;
  final DwFieldPatch<String>? nullablePatch;
  final DwFieldPatch<String?> patchOfNullable;
  final DwFieldPatch<List<int>> patchOfList;
  final List<Uint8List> bytesList;
  final AbstractView abstractView;
  final num number;
  final Object object;
}
