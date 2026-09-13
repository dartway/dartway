import 'package:dartway_core/dartway_core.dart';

import 'visible.dart' show Visible;

part 'hidden.dw.dart';

final class UsesHidden extends DwCommand<void> with _$UsesHidden {
  const UsesHidden({required this.visible});

  final Visible visible;
}
