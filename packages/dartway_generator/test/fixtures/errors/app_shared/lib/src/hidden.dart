import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'visible.dart' show Visible;

part 'hidden.dw.dart';

final class UsesHidden extends DwActionCommand<void> with _$UsesHidden {
  const UsesHidden({required this.visible});

  final Visible visible;
}
